package hxd.res;

#if (air3 || sys)

@:allow(hxd.res.LocalFileSystem)
@:access(hxd.res.LocalFileSystem)
private class LocalEntry extends FileEntry {

	var fs : LocalFileSystem;
	var relPath : String;
	var needUnzip : Bool;
	#if air3
	var file : flash.filesystem.File;
	var fread : flash.filesystem.FileStream;
	#else
	var file : String;
	var fread : sys.io.FileInput;
	#end

	function new(fs, name, relPath, file) {
		this.fs = fs;
		this.name = name;
		this.relPath = relPath;
		this.file = file;
		if( fs.createXBX && extension == "fbx" )
			convertToXBX();
		if( fs.createMP3 && extension == "wav" )
			convertToMP3();
	}

	static var INVALID_CHARS = ~/[^A-Za-z0-9_]/g;

	function convertToXBX() {
		function getXBX() {
			var fbx = null;
			try fbx = h3d.fbx.Parser.parse(getBytes().toString()) catch( e : Dynamic ) throw Std.string(e) + " in " + relPath;
			fbx = fs.xbxFilter(this, fbx);
			var out = new haxe.io.BytesOutput();
			new h3d.fbx.XBXWriter(out).write(fbx);
			return out.getBytes();
		}
		var target = fs.tmpDir + "R_" + INVALID_CHARS.replace(relPath, "_") + ".xbx";
		needUnzip = fs.compressXBX;
		#if air3
		if( fs.releaseBuild ) {
			file = fs.open(target);
			if( file == null ) throw "Missing file " + target;
			return;
		}
		var target = new flash.filesystem.File(target);
		if( !target.exists || target.modificationDate.getTime() < file.modificationDate.getTime() ) {
			var xbx = getXBX();
			if( fs.compressXBX ) xbx = haxe.zip.Compress.run(xbx, 9);
			var out = new flash.filesystem.FileStream();
			out.open(target, flash.filesystem.FileMode.WRITE);
			out.writeBytes(xbx.getData());
			out.close();
		}
		file = target;
		#else
		var ttime = try sys.FileSystem.stat(target) catch( e : Dynamic ) null;
		if( ttime == null || ttime.mtime.getTime() < sys.FileSystem.stat(file).mtime.getTime() ) {
			var xbx = getXBX();
			if( fs.compressXBX ) xbx = haxe.zip.Compress.run(xbx, 9);
			sys.io.File.saveBytes(target, xbx);
		}
		#end
	}

	function convertToMP3() {
		var target = fs.tmpDir + "R_" + INVALID_CHARS.replace(relPath,"_") + ".mp3";
		#if air3
		if( fs.releaseBuild ) {
			file = fs.open(target);
			if( file == null ) throw "Missing file " + target;
			return;
		}
		var target = new flash.filesystem.File(target);
		if( !target.exists || target.modificationDate.getTime() < file.modificationDate.getTime() ) {
			var p = new flash.desktop.NativeProcess();
			var i = new flash.desktop.NativeProcessStartupInfo();
			i.arguments = flash.Vector.ofArray(["-h",file.nativePath,target.nativePath]);
			var f = new flash.filesystem.File("d:/projects/shiroTools/tools/lame.exe");
			i.executable = f;
			i.workingDirectory = f.parent;
			p.addEventListener("exit", function(e:Dynamic) {
				var code : Int = Reflect.field(e, "exitCode");
				if( code == 0 )
					file = target;
			});
			p.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) {
				trace(e);
			});
			p.start(i);
			trace("Started");
		} else
			file = target;
		#end
	}

	override function getSign() : Int {
		#if air3
		var old = fread == null ? -1 : fread.position;
		open();
		fread.endian = flash.utils.Endian.LITTLE_ENDIAN;
		var i = fread.readUnsignedInt();
		if( old < 0 ) close() else fread.position = old;
		return i;
		#else
		var old = if( fread == null ) -1 else fread.tell();
		open();
		var i = fread.readInt32();
		if( old < 0 ) close() else fread.seek(old, SeekBegin);
		return i;
		#end
	}

	override function getBytes() : haxe.io.Bytes {
		#if air3
		var fs = new flash.filesystem.FileStream();
		fs.open(file, flash.filesystem.FileMode.READ);
		var bytes = haxe.io.Bytes.alloc(fs.bytesAvailable);
		fs.readBytes(bytes.getData());
		fs.close();
		if( needUnzip )
			return haxe.zip.Uncompress.run(bytes);
		return bytes;
		#else
		return sys.io.File.getBytes(file);
		#end
	}

	override function open() {
		#if air3
		if( fread != null )
			fread.position = 0;
		else {
			fread = new flash.filesystem.FileStream();
			fread.open(file, flash.filesystem.FileMode.READ);
		}
		#else
		if( fread != null )
			fread.seek(0, SeekBegin);
		else
			fread = sys.io.File.read(file);
		#end
	}

	override function skip(nbytes:Int) {
		#if air3
		fread.position += nbytes;
		#else
		fread.seek(nbytes, SeekCur);
		#end
	}

	override function readByte() {
		#if air3
		return fread.readUnsignedByte();
		#else
		return fread.readByte();
		#end
	}

	override function read( out : haxe.io.Bytes, pos : Int, size : Int ) : Void {
		#if air3
		fread.readBytes(out.getData(), pos, size);
		#else
		fread.readFullBytes(out, pos, size);
		#end
	}

	override function close() {
		#if air3
		if( fread != null ) {
			fread.close();
			fread = null;
		}
		#else
		if( fread != null ) {
			fread.close();
			fread = null;
		}
		#end
	}

	override function get_isDirectory() {
		#if air3
		return file.isDirectory;
		#else
		throw "TODO";
		return false;
		#end
	}

	override function load( ?onReady : Void -> Void ) : Void {
		#if air3
		if( onReady != null ) haxe.Timer.delay(onReady, 1);
		#else
		throw "TODO";
		#end
	}

	override function loadBitmap( onLoaded : hxd.BitmapData -> Void ) : Void {
		#if flash
		var loader = new flash.display.Loader();
		loader.contentLoaderInfo.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e:flash.events.IOErrorEvent) {
			throw Std.string(e) + " while loading " + relPath;
		});
		loader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, function(_) {
			var content : flash.display.Bitmap = cast loader.content;
			onLoaded(hxd.BitmapData.fromNative(content.bitmapData));
			loader.unload();
		});
		loader.load(new flash.net.URLRequest(file.url));
		#else
		throw "TODO";
		#end
	}

	override function get_path() {
		return relPath == null ? "<root>" : relPath;
	}

	override function exists( name : String ) {
		return fs.exists(relPath == null ? name : relPath + "/" + name);
	}

	override function get( name : String ) {
		return fs.get(relPath == null ? name : relPath + "/" + name);
	}

	override function get_size() {
		#if air3
		return Std.int(file.size);
		#else
		return sys.FileSystem.stat(file).size;
		#end
	}

	override function iterator() {
		#if air3
		var arr = new Array<FileEntry>();
		for( f in file.getDirectoryListing() )
			switch( f.name ) {
			case ".svn", ".git" if( f.isDirectory ):
				continue;
			default:
				arr.push(new LocalEntry(fs, f.name, relPath == null ? f.name : relPath + "/" + f.name, f));
			}
		return new hxd.impl.ArrayIterator(arr);
		#else
		var arr = new Array<FileEntry>();
		for( f in sys.FileSystem.readDirectory(file) ) {
			switch( f ) {
			case ".svn", ".git" if( sys.FileSystem.isDirectory(file+"/"+f) ):
				continue;
			default:
				arr.push(new LocalEntry(fs, f, relPath == null ? f : relPath + "/" + f, file+"/"+f));
			}
		}
		return new hxd.impl.ArrayIterator(arr);
		#end
	}

	#if air3

	var watchCallback : Void -> Void;
	var watchTime : Float;
	static var WATCH_LIST : Array<LocalEntry> = null;

	static function checkFiles(_) {
		for( w in WATCH_LIST ) {
			var t = try w.file.modificationDate.getTime() catch( e : Dynamic ) -1;
			if( t != w.watchTime ) {
				// check we can write (might be deleted/renamed/currently writing)
				try {
					var f = new flash.filesystem.FileStream();
					f.open(w.file, flash.filesystem.FileMode.READ);
					f.close();
					f.open(w.file, flash.filesystem.FileMode.APPEND);
					f.close();
				} catch( e : Dynamic ) continue;
				w.watchTime = t;
				w.watchCallback();
			}
		}
	}

	override function watch( onChanged : Null < Void -> Void > ) {
		if( onChanged == null ) {
			if( watchCallback != null ) {
				WATCH_LIST.remove(this);
				watchCallback = null;
			}
			return;
		}
		if( watchCallback == null ) {
			if( WATCH_LIST == null ) {
				WATCH_LIST = [];
				flash.Lib.current.stage.addEventListener(flash.events.Event.ENTER_FRAME, checkFiles);
			}
			var path = path;
			for( w in WATCH_LIST )
				if( w.path == path ) {
					w.watchCallback = null;
					WATCH_LIST.remove(w);
				}
			WATCH_LIST.push(this);
		}
		watchTime = file.modificationDate.getTime();
		watchCallback = onChanged;
		return;
	}

	#end

}

class LocalFileSystem implements FileSystem {

	var root : FileEntry;
	var baseDir(default,null) : String;
	var tmpDir : String;
	public var createXBX : Bool;
	public var createMP3 : Bool;
	public var compressXBX : Bool;
	public var releaseBuild : Bool;

	public function new( dir : String ) {
		baseDir = dir;
		#if air3
		var path = flash.filesystem.File.applicationDirectory.nativePath;
		var froot = path == "" ? flash.filesystem.File.applicationDirectory.resolvePath(baseDir) : new flash.filesystem.File(path + "/" + baseDir);
		if( !froot.exists ) throw "Could not find dir " + dir;
		baseDir = froot.nativePath;
		baseDir = baseDir.split("\\").join("/");
		if( !StringTools.endsWith(baseDir, "/") ) baseDir += "/";
		root = new LocalEntry(this, "root", null, froot);
		if( baseDir == "/" ) baseDir = ""; // use relative paths on Android !!
		#else
		var exePath = Sys.executablePath().split("\\").join("/").split("/");
		exePath.pop();
		var froot = sys.FileSystem.fullPath(exePath.join("/") + "/" + baseDir);
		if( !sys.FileSystem.isDirectory(froot) ) throw "Could not find dir " + dir;
		baseDir = froot.split("\\").join("/");
		if( !StringTools.endsWith(baseDir, "/") ) baseDir += "/";
		root = new LocalEntry(this, "root", null, baseDir);
		#end
		tmpDir = baseDir + ".tmp/";
	}

	public dynamic function xbxFilter( entry : FileEntry, fbx : h3d.fbx.Data.FbxNode ) : h3d.fbx.Data.FbxNode {
		return fbx;
	}

	public function getRoot() : FileEntry {
		return root;
	}

	function open( path : String ) {
		#if air3
		if( baseDir == "" ) {
			var f = cast(root,LocalEntry).file.resolvePath(path);
			if( !f.exists ) return null;
			return f;
		}
		var f = new flash.filesystem.File(baseDir + path);
		// ensure exact case / no relative path
		f.canonicalize();
		if( f.nativePath.split("\\").join("/") != baseDir + path )
			return null;
		return f;
		#else
		var f = sys.FileSystem.fullPath(baseDir + path).split("\\").join("/");
		if( f != baseDir + path )
			return null;
		return f;
		#end
	}

	public function exists( path : String ) {
		#if air3
		var f = open(path);
		return f != null && f.exists;
		#else
		var f = open(path);
		return f != null && sys.FileSystem.exists(f);
		#end
	}

	public function get( path : String ) {
		#if air3
		var f = open(path);
		if( f == null || !f.exists )
			throw new NotFound(path);
		return new LocalEntry(this, path.split("/").pop(), path, f);
		#else
		var f = open(path);
		if( f == null ||!sys.FileSystem.exists(f) )
			throw new NotFound(path);
		return new LocalEntry(this, path.split("/").pop(), path, f);
		#end
	}

}

#else

class LocalFileSystem implements FileSystem {

	public var baseDir(default,null) : String;

	public function new( dir : String ) {
		#if flash
		if( flash.system.Capabilities.playerType == "Desktop" )
			throw "Please compile with -lib air3";
		#end
		throw "Local file system is not supported for this platform";
	}

	public function exists(path:String) {
		return false;
	}

	public function get(path:String) : FileEntry {
		return null;
	}

	public function getRoot() : FileEntry {
		return null;
	}
}

#end