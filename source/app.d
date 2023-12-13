/+

MIT License

Copyright (c) 2023 Andrea Fontana

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

+/

import std;
import core.atomic, core.thread;
import std.digest.sha;
import arsd.qrcode;

immutable VERSION = "tshare/1.1";
immutable VERSION_EXT = "tshare/1.1 (https://tshare.download)";

enum RuntimeErrors
{
	CurlError 		= -1,
	HttpError 		= -2,
	BadReply 		= -3,
	GpgNotFound 	= -4,
	CurlNotFound	= -5,
	FileEmpty		= -6,
	CantUpgrade		= -7
}

int main(string[] args)
{
	// Password privacy
	foreach(k,v; args)
	{
		if ((v == "-c" || v == "--crypt") && k+1 < args.length)
		{
			import core.runtime : Runtime;

			auto p = args[k+1];
			Runtime.cArgs.argv[k+1][0..p.length][] = repeat('*').take(p.length).array[];
		}
	}

	// Enable terminal colors on older windows
	version(Windows)
	{
		import core.sys.windows.windows;

		DWORD dwMode;
		HANDLE hOutput = GetStdHandle(STD_OUTPUT_HANDLE);

		GetConsoleMode(hOutput, &dwMode);
      dwMode |= ENABLE_PROCESSED_OUTPUT | ENABLE_VIRTUAL_TERMINAL_PROCESSING;
		SetConsoleMode(hOutput, dwMode);
	}

	// Check if curl is available
	{
		try { auto test = HTTP("https://example.org"); }
		catch (CurlException e)
		{
			stderr_writeln("\r\x1b[1m\x1b[31mError: libcurl not found.\x1b[0m Install curl/libcurl on your system");
			return RuntimeErrors.CurlNotFound;
		}
	}

	// Simple checks on url format
	immutable urlRegex = "^https://transfer.sh/[a-z0-9A-Z]+/[^/]+$";
	immutable deleteUrlRegex = "^https://transfer.sh/[a-z0-9A-Z]+/[^/]+/[a-z0-9A-Z]+$";

	bool 		showHelp = false;

	string	path;			// The file you're uploading
	string	destName;	// Sometimes you want to change the name of remote file
	string 	deleteUrl;	// If you want to delete an upload file

	size_t 	maxDownloads 	= size_t.max;
	size_t 	maxDays 			= size_t.max;
	bool		upgrade			= false;
	bool		printVersion	= false;
	bool		fromStdin		= false;
	bool		qrcode 			= false;
	string	crypt 			= string.init;
	string 	output			= string.init;

	shared size_t		statsData = 0;
	shared size_t[10]	statsHistory;
	shared size_t		statsHistoryIdx = 0;

	shared float		speed = float.nan;

	version(Windows) 	immutable canDrawQR = false;
	else 					immutable canDrawQR = environment.get("LANG", string.init).endsWith(".UTF-8");

	try {
		auto info = getopt(
			args,
			"d", &maxDownloads,
			"t", &maxDays,
			"o|output", &output,
			"stdin", &fromStdin,
			"r|remove", &deleteUrl,
			"c|crypt", &crypt,
			"s|silent", &silent,
			"upgrade", &upgrade,
			"version", &printVersion,
			"qrcode", &qrcode
		);

		size_t commands = 0;

		// They ask --help
		showHelp = info.helpWanted;

		// You can't mix different commands
		if (!showHelp)
		{
			if (!deleteUrl.empty) commands++;

			if (
				maxDownloads != size_t.max || maxDays != size_t.max
				|| !crypt.empty || !output.empty || fromStdin || qrcode || args.length == 2
			) commands++;

			if (printVersion) commands++;

			if (upgrade) commands++;

			if (commands != 1)
				showHelp = true;
		}

		// --version
		if (!showHelp && printVersion)
		{
			if (args.length == 1)
			{
				writeln(VERSION_EXT);
				return 0;
			}

			showHelp = true;
		}

		// --version
		if (!showHelp && upgrade)
		{
			if (args.length == 1)
			{
				import std.digest.sha : SHA256;

				File myself = File(thisExePath, "r");
				SHA256 sha;
				ubyte[4096] data;

				sha.start();
				while(!myself.eof)
				{
					auto slice = myself.rawRead(data);
					sha.put(slice);
				}

				string check;
				string hash = sha.finish()[].toHexString().toLower();
				stderr_writeln("\x1b[1mRunning version:\x1b[0m ", hash);

				version(linux) auto uri = "tshare-linux-x86_64";
				else version(Windows) auto uri = "tshare-windows-x86_64";
				else version(OSX) auto uri = "tshare-macos-x86_64";
				else auto uri = "";

				uri = ("https://github.com/trikko/tshare/releases/latest/download/" ~ uri ~ ".sha256");


				try {
					check = cast(string) get(uri).chomp;
					stderr_writeln("\x1b[1m Latest version:\x1b[0m ", check, "\n");
				}
				catch (Exception e)
				{
					stderr_writeln("\x1b[1m\x1b[31mError: can't check for new updates.\x1b[0m");
					return RuntimeErrors.CantUpgrade;
				}

				if (check != hash)
				{
					string upgradeCmd;
					version(Windows) upgradeCmd = "curl -L https://tshare.download/windows.zip -o tshare.zip";
					else upgradeCmd = "curl https://tshare.download | bash";

					if (silent) writeln(upgradeCmd);
					else writeln("\x1b[32mNew version available, upgrade tshare now:\n\x1b[0m\x1b[1m", upgradeCmd, "\x1b[0m");
				}
				else stderr_writeln("\x1b[1mtshare is \x1b[32mup-to-date\x1b[0m");

				return 0;
			}

			showHelp = true;
		}

		// -r https://transfer.sh/.../
		if (!showHelp && !deleteUrl.empty)
		{
			if (args.length == 1 && match("https://transfer.sh/" ~ deleteUrl, deleteUrlRegex))
			{
				auto http = HTTP("https://transfer.sh/" ~ deleteUrl);

				// Ignore output
				http.onReceive = (ubyte[] data) { return data.length; };

				// HTTP DELETE
				http.method = HTTP.Method.del;
				auto r = http.perform(No.throwOnError);

				if (r != 0)
				{
					stderr_writeln("\x1b[1m\x1b[31mError deleting\x1b[0m (CURL error: ", r, ")");
					return RuntimeErrors.CurlError;
				}

				if (http.statusLine.code != 200)
				{
					stderr_writeln("\x1b[1m\x1b[31mError deleting\x1b[0m (HTTP status: ", http.statusLine.code, ")");
					return RuntimeErrors.HttpError;
				}

				stderr_writeln("\x1b[1mFile deleted.\x1b[0m");
				return 0;
			}

			showHelp = true;
		}

		// --stdin
		if (!showHelp && fromStdin)
		{
			if (!output.empty) destName = output;
			else showHelp = true;
		}

		// from file
		else if (!showHelp)
		{
			if(args.length >= 2 && args.length <= 3)
			{
				// Getting args
				path = absolutePath(args[1]);
				destName = baseName(path);

				if (!output.empty) destName = output;

				// Extra checks
				if (!path.exists || !isFile(path))
					showHelp = true;
			}

			else showHelp = true;
		}

	}
	catch(Exception e) { showHelp = true; }

	if(showHelp)
	{
		string help = "\x1b[32m" ~ VERSION_EXT ~ " \x1b[0m\nFast file sharing, using transfer.sh\x1b[0m\n\n\x1b[32mUsage:\x1b[0m
tshare <local-file-path> \x1b[2m[OPTIONS...]\x1b[0m
tshare --stdin -o <remote-file-name> \x1b[2m[OPTIONS...]\x1b[0m
tshare -r <token> \x1b[2m[--silent]\x1b[0m
tshare --upgrade \x1b[2m[--silent]\x1b[0m
tshare --version

\x1b[32mOptions:\x1b[0m
 \x1b[1m          -d\x1b[0m  <n>      Set the max number of downloads for this file.
 \x1b[1m          -t\x1b[0m  <days>   Set the lifetime of this file.
 \x1b[1m--output, -o\x1b[0m  <name>   Set the filename used for sharing.
 \x1b[1m--crypt,  -c\x1b[0m           Crypt your file using gpg, if installed.
 \x1b[1m--silent, -s\x1b[0m           Less verbose, minimal output.
 \x1b[1m--remove, -r\x1b[0m  <token>  Delete and uploaded file, using a token.
 \x1b[1m--qrcode    \x1b[0m           Output a QR code.
 \x1b[1m--stdin     \x1b[0m           Read input from stdin.
 \x1b[1m--upgrade   \x1b[0m           Is there a new tshare version available?

\x1b[32mExamples:\x1b[0m
tshare /tmp/file1.txt                \x1b[1m# Share /tmp/file1.txt\x1b[0m
tshare -t 3 /tmp/file2.txt           \x1b[1m# This file will be deleted in 3 days\x1b[0m
tshare /tmp/file3.txt -o hello.txt   \x1b[1m# Uploaded as \"hello.txt\"\x1b[0m
";

		writeln(help);
		return 0;
	}

	// Check if gpg is available
	if (crypt.length > 0)
	{
		bool hasgpg = false;

		try {
			auto result = execute(["gpg", "--version"]);

			if (result.status == 0)
			{
				auto lsplit = result.output.split("\n");
				if (lsplit.length > 0)
				{
					auto vsplit = lsplit[0].split(" ");
					if (vsplit.length > 0 && vsplit[$-1].startsWith("2.")) hasgpg = true;
				}
			}
		} catch(Exception e) { hasgpg = false; }

		if (!hasgpg)
		{
			stderr_writeln("\r\x1b[1m\x1b[31mCan't crypt data\x1b[0m (gpg >= 2.0.0 not found)");
			return RuntimeErrors.GpgNotFound;
		}
	}

	bool uploading = true;
	scope(exit) uploading = false;

	// Thread for speed stats
	new Thread({

		auto started = Clock.currTime;

		while(uploading)
		{
			Thread.sleep(500.msecs);

			auto last = atomicLoad(statsData);
			statsHistory[statsHistoryIdx] = last;

			if (Clock.currTime - started > 5.seconds)
			{
				size_t total = 0;
				auto startIdx = (statsHistoryIdx + 1) % 10;

				foreach(i; 0..4)
					total += statsHistory[(startIdx+i+1) % 10] - statsHistory[(startIdx+i) % 10];

				atomicStore(speed, total/5.0f);
			}

			statsHistoryIdx = (statsHistoryIdx + 1) % 10;
		}
	}).start();

	// Here we go. Check the file to upload.
	File file;

	if (fromStdin) file = stdin;
	else file = File(path);

	if (crypt.length > 0)
	{
		if (output.empty)
			destName ~= ".gpg";

		stderr.write("\x1b[2K\r\x1b[1mEncrypting, please wait...\x1b[0m");

		// Temporary and anonymous file, without even a name.
		File buffer;
		File ignored;
		bool needDelete = false;

		try {
			buffer = File.tmpfile();
			ignored = File.tmpfile();
		} catch(Exception e) {
			// Probably we're on an android device, so we can't use tmpfile()
			string tmpdir = environment.get("TMPDIR");
			buffer = File(buildPath(tmpdir, "tmp-" ~ randomUUID().toString), "w+");
			ignored = File(buildPath(tmpdir, "ignored-" ~ randomUUID().toString), "w+");
			needDelete = true;
		}

		// Clean up tmp files on exit if needed
		scope(exit)
		{
			if (needDelete)
			{
				remove(buffer.name);
				remove(ignored.name);
			}
		}

		auto pid = spawnProcess(["gpg", "-c", "--batch", "--passphrase", crypt, "-o", "-"], file, buffer, ignored, string[string].init, Config.retainStdout);

		while(!pid.tryWait.terminated)
		{
			if (!buffer.isOpen) break;

			ulong done;
			try { done = buffer.tell*100;}
			catch(Exception e) { break; }

			immutable sizes = ["bytes", "KB", "MB", "GB", "TB"];
			size_t curSize;
			foreach(k, s; sizes)
			{
				curSize = k;
				if (done > 1024*100) done /= 1024;
				else break;
			}

			stderr.write("\x1b[2K\r\x1b[1mEncrypting, please wait...\x1b[0m " ~ format("%.2f", done*1.0f/100) ~ " " ~ sizes[curSize]);
			Thread.sleep(500.msecs);
		}

		int r = pid.wait();
		file = buffer;
		file.rewind();
	}

	bool	 isEmptyFile = true;
	ulong  fileSize = file.size;
	scope(exit) file.close();

	// Build the request
	auto http = HTTP("https://transfer.sh/" ~ encodeComponent(destName));

	if(maxDays < size_t.max)
		http.addRequestHeader("max-days", maxDays.to!string);

	if(maxDownloads < size_t.max)
		http.addRequestHeader("max-downloads", maxDownloads.to!string);

	http.method = HTTP.Method.put;
	http.setUserAgent(VERSION_EXT);

	ubyte[] response;
	response.reserve(1024);

	if (fileSize < size_t.max)
		http.contentLength = fileSize;

	http.onSend = (void[] data)
	{
		auto slice = file.rawRead(data);
		return slice.length;
	};

	http.onReceive = (ubyte[] data)
	{
		response ~= data;
		return data.length;
	};

	http.onReceiveHeader = (in char[] key, in char[] value)
	{
		if (key.toLower == "x-url-delete")
			deleteUrl = value.to!string;
	};

	http.onProgress = (size_t dltotal, size_t dlnow, size_t ultotal, size_t ulnow)
	{
		if (isEmptyFile && ulnow > 0)
			isEmptyFile = false;

		if (silent)
			return 0;

		atomicStore(statsData, ulnow);

		immutable um = ["B/s", "KB/s", "MB/s", "GB/s"];
		auto umIdx = 0;
		auto curSpeed = atomicLoad(speed);

		if (!curSpeed.isNaN)
		{
			while(curSpeed > 1024 && umIdx < um.length)
			{
				curSpeed /= 1024;
				umIdx++;
			}
		}

		if (fileSize < size_t.max)
		{
			if (ulnow == fileSize) stderr.write("\x1b[2K\r\x1b[1mUpload completed. Waiting for link...\x1b[0m");
			else if (curSpeed.isNaN) stderr.write(format("\x1b[2K\r\x1b[1mProgress:\x1b[0m %5.1f%%", (ulnow*1.0f/fileSize)*100.0f));
			else stderr.write(format("\x1b[2K\r\x1b[1mProgress:\x1b[0m %5.1f%% \x1b[1m\tSpeed:\x1b[0m %6.1f %s", (ulnow*1.0f/fileSize)*100.0f, curSpeed, um[umIdx]));
		}
		else
		{
			if (curSpeed.isNaN) stderr.write(format("\x1b[2K\r\x1b[1mProgress:\x1b[0m %s bytes", ultotal));
			else stderr.write(format("\x1b[2K\r\x1b[1mProgress:\x1b[0m %s bytes \x1b[1m\tSpeed:\x1b[0m %6.1f %s", ultotal, curSpeed, um[umIdx]));
		}

		return 0;
	};

	auto code = http.perform(No.throwOnError);

	if (code != 0)
	{
		stderr_writeln("\r\x1b[1m\x1b[31mUpload failed\x1b[0m (CURL error: ", code, ")");
		return RuntimeErrors.CurlError;
	}

	if (http.statusLine.code != 200)
	{
		if (isEmptyFile)
		{
			stderr_writeln("\r\x1b[1m\x1b[31mError: can't upload an empty file\x1b");
			return RuntimeErrors.FileEmpty;
		}
		else
		{
			stderr_writeln("\r\x1b[1m\x1b[31mUpload failed\x1b[0m (HTTP status: ", http.statusLine.code, ")");
			return RuntimeErrors.HttpError;
		}
	}

	// ALL DONE!
	uploading = false;
	auto url = (cast(char[])response).to!string;

	if (!url.match(urlRegex) || !deleteUrl.match(deleteUrlRegex))
	{
		stderr_writeln("\r\x1b[1m\x1b[31mUpload failed\x1b[0m (bad data from server)");
		return RuntimeErrors.BadReply;
	}

	if (!silent)
	{
		stderr_write("\r\x1b[1mUpload:\x1b[0m Completed. Yay!");
		write("\x1b[2K\r");
		writeln();

		if (qrcode)
		{
			if (!canDrawQR) writeln("\x1b[2mCan't draw a QR code in this terminal :(\x1b[0m");
			else
			{
				import arsd.qrcode;
				QrCode q = QrCode(url);

				immutable sotto = "\342\226\204";
				immutable sopra = "\342\226\200";
				immutable pieno = "\342\226\210";
				immutable vuoto = " ";

				int rows = (q.size() + 1)/2;

				foreach(y; 0..rows)
				{
					foreach(x; 0..q.size())
					{
						auto y1 = y*2;
						auto y2 = y*2+1;

						if (!q[x,y1] && !q[x,y2]) 			write(pieno);
						else if (q[x,y1] && q[x,y2])		write(vuoto);
						else if (q[x,y2]) 					write(sopra);
						else if (q[x,y1])  					write(sotto);

					}
					writeln();
				}
			}

			writeln();
		}


		writeln("\r\x1b[1mLink:\x1b[32m ", url, " \x1b[0m");
		writeln("\r\x1b[1mTo remove:\x1b[0m " ~ baseName(args[0]) ~ " -r ", deleteUrl["https://transfer.sh/".length .. $]);

		writeln();
	}
	else {
		writeln(url);
		writeln("tshare -r ", deleteUrl["https://transfer.sh/".length .. $]);
	}

	return 0;
}

bool 		silent = false; // --silent switch
void stderr_writeln(T...)(T p) { if (!silent)  stderr.writeln(p, "\x1b[0K"); }
void stderr_write(T...)(T p) { if (!silent) stderr.write(p, "\x1b[0K"); }
