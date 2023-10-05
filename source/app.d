import std;

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

	try {
		auto info = getopt(
			args,
			"d", "Max downloads",  &maxDownloads,
			"t", "Lifetime in days",   &maxDays,
			"r", "Remove an upload, using a token", &deleteUrl,
			"version", "Print version", &printVersion
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
			http.onReceive(  (ubyte[] data) { return data.length; });

			// HTTP DELETE
			http.method = HTTP.Method.del;
			auto r = http.perform(No.throwOnError);

			if (r == 0 && http.statusLine.code == 200) stderr.writeln("File deleted.");
			else stderr.writeln("Error deleting. (Return code: ", r, " / HTTP ", http.statusLine.code, ")");

			return r;
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
		stderr.writeln("Usage: tshare [-d max-downloads] [-t max-days] <local-file-path> [remote-file-name]\n       tshare -r <token>\n       tshare --version");
		return 0;
	}

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
		if (fileSize < size_t.max) stderr.write(format("\r\x1b[1mUpload:\x1b[0m %0.1f%%  ", (ulnow*1.0f/fileSize)*100.0f));
		else stderr.write(format("\r\x1b[1mUpload:\x1b[0m %s bytes", ulnow));
		return 0;
	};

	auto code = http.perform(No.throwOnError);

	if (code != 0 || http.statusLine.code != 200)
	{
		stderr.writeln("\\r\x1b[1mUpload:\x1b[31m Failed. Error during upload.\x1b[0m (Return code: ", code,  " / HTTP ", http.statusLine.code, ")");
		return code;
	}

	// ALL DONE!
	auto url = (cast(char[])response).to!string;
	stderr.write("\r\x1b[1mUpload:\x1b[0m Completed. Yay!");

	if (url.match(urlRegex))
		writeln("\r\x1b[1mLink:\x1b[32m ", url, " \x1b[0m");

	if(deleteUrl.match(deleteUrlRegex))
		writeln("\r\x1b[1mTo remove:\x1b[0m tshare -r ", deleteUrl["https://transfer.sh/".length .. $]);

	return 0;

}
