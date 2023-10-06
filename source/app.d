import std;
import core.atomic, core.thread;

immutable VERSION = "tshare/1.0";
immutable VERSION_EXT = "tshare/1.0 (https://github.com/trikko/tshare)";

int main(string[] args)
{
	// Simple checks on url format
	immutable urlRegex = "^https://transfer.sh/[a-z0-9A-Z]+/[^/]+$";
	immutable deleteUrlRegex = "^https://transfer.sh/[a-z0-9A-Z]+/[^/]+/[a-z0-9A-Z]+$";

	bool 		valid = true;

	string	path;			// The file you're uploading
	string	destName;	// Sometimes you want to change the name of remote file
	string 	deleteUrl;	// If you want to delete an upload file

	size_t 	maxDownloads = size_t.max;
	size_t 	maxDays = size_t.max;
	bool		printVersion;

	shared size_t		statsData = 0;
	shared size_t[10]	statsHistory;
	shared size_t		statsHistoryIdx = 0;

	shared float		speed = float.nan;

	try {
		auto info = getopt(
			args,
			"d", &maxDownloads,
			"t", &maxDays,
			"r", &deleteUrl,
			"silent", &silent,
			"version", &printVersion
		);

		// --version
		if (printVersion)
		{
			writeln(VERSION_EXT);
			return 0;
		}

		// tshare -r https://transfer.sh/.../
		if (
				maxDays == size_t.max
				&& maxDownloads == size_t.max
				&& args.length == 1
				&& (("https://transfer.sh/" ~ deleteUrl).match(deleteUrlRegex))
		)
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
				return -1;
			}

			if (http.statusLine.code != 200)
			{
				stderr_writeln("\x1b[1m\x1b[31mError deleting\x1b[0m (HTTP status: ", http.statusLine.code, ")");
				return -2;
			}

			stderr_writeln("\x1b[1mFile deleted.\x1b[0m");

			return 0;
		}

		// Normal run -->
		if (args.length < 2 || args.length > 3 || info.helpWanted)
		{
			valid = false;
		}
		else
		{
			// Getting args
			path = absolutePath(args[1]);
			destName = baseName(path);

			if (args.length == 3) destName = args[2];

			// Extra checks
			if (!path.exists || !isFile(path))
				valid = false;
		}

	}
	catch(Exception e) { valid = false; }

	if(!valid)
	{
		stderr.writeln("\x1b[32mFast file sharing, using transfer.sh\x1b[0m\n\x1b[1mhttps://github.com/trikko/tshare\x1b[0m\n\n\x1b[32mUsage:\x1b[0m
tshare \x1b[2m[--silent] [-d max-downloads] [-t time-to-live-in-days]\x1b[0m <local-file-path> \x1b[2m[remote-file-name]\x1b[0m
tshare \x1b[2m[--silent]\x1b[0m -r <token>
tshare --version

\x1b[32mExamples:\x1b[0m
tshare /tmp/file1.txt              \x1b[1m# Share /tmp/file1.txt\x1b[0m
tshare -t 3 /tmp/file2.txt         \x1b[1m# This file will be deleted in 3 days\x1b[0m
tshare /tmp/file3.txt hello.txt    \x1b[1m# Uploaded as \"hello.txt\"\x1b[0m
");
		return 0;
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
	File file = File(path);
	size_t fileSize = file.size;

	// Build the request
	auto http = HTTP("https://transfer.sh/" ~ destName);

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
		if (silent)
			return 0;

		atomicStore(statsData, ulnow);

		immutable um = ["b/s", "Kb/s", "Mb/s", "Gb/s"];
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
			else if (curSpeed.isNaN) stderr.write(format("\x1b[2K\r\x1b[1mProgress:\x1b[0m %5.1f%% \x1b[1m", (ulnow*1.0f/fileSize)*100.0f));
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
		return -1;
	}

	if (http.statusLine.code != 200)
	{
		stderr_writeln("\r\x1b[1m\x1b[31mUpload failed\x1b[0m (HTTP status: ", http.statusLine.code, ")");
		return -2;
	}

	// ALL DONE!
	uploading = false;
	auto url = (cast(char[])response).to!string;

	if (!url.match(urlRegex) || !deleteUrl.match(deleteUrlRegex))
	{
		stderr_writeln("\r\x1b[1m\x1b[31mUpload failed\x1b[0m (bad data from server)");
		return -3;
	}

	if (!silent)
	{
		stderr_write("\r\x1b[1mUpload:\x1b[0m Completed. Yay!");
		writeln("\r\x1b[1mLink:\x1b[32m ", url, " \x1b[0m");
		writeln("\r\x1b[1mTo remove:\x1b[0m tshare -r ", deleteUrl["https://transfer.sh/".length .. $]);
	}
	else {
		writeln(url);
		writeln("tshare -r ", deleteUrl["https://transfer.sh/".length .. $]);
	}

	return 0;
}

bool silent = false; // --silent switch
void stderr_writeln(T...)(T p) { if (!silent) stderr.writeln(p); }
void stderr_write(T...)(T p) { if (!silent) stderr.write(p); }

