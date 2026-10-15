# Copyright © 2026 medissl. All rights reserved.
# Original material only; see LICENSE.txt and THIRD_PARTY_NOTICES.md.
extends SceneTree

func collect_notices(path: String, files: Array[String]) -> void:
	for filename in DirAccess.get_files_at(path):
		if filename.get_extension() in ["txt", "json"]:
			files.append(path.path_join(filename))
	for folder in DirAccess.get_directories_at(path):
		collect_notices(path.path_join(folder), files)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if "--generate" in args:
		var out := FileAccess.open("res://licenses/GODOT_THIRD_PARTY_NOTICES.txt", FileAccess.WRITE)
		out.store_string("Godot " + Engine.get_version_info().string + "\nEngine and bundled library notices from this installed engine build.\nRegenerate and compare when changing export templates or native modules.\n\n" + Engine.get_license_text() + "\n\n")
		for component in Engine.get_copyright_info():
			out.store_string(str(component.name) + "\n")
			for part in component.parts:
				out.store_string("Files: " + ", ".join(part.files) + "\n" + "\n".join(part.copyright) + "\nLicense: " + str(part.license) + "\n\n")
		var texts := Engine.get_license_info()
		for name in texts:
			out.store_string(str(name) + "\n" + str(texts[name]) + "\n\n")
		out.close()
		print("Engine copyright and full component license texts saved.")
		quit()
		return
	var hashes := {}
	if args.size() == 2 and args[0] == "--write-manifest":
		var files: Array[String] = ["res://LICENSE.txt", "res://THIRD_PARTY_NOTICES.md", "res://ASSET_SOURCES.md"]
		collect_notices("res://licenses", files)
		collect_notices("res://assets", files)
		for path in files:
			hashes[path] = FileAccess.get_sha256(path)
		var manifest := FileAccess.open(args[1], FileAccess.WRITE)
		manifest.store_string(JSON.stringify(hashes))
		manifest.close()
		quit()
		return
	if args.size() != 3 or args[0] != "--verify-pack":
		push_error("Usage: -- --generate, --write-manifest <path>, or --verify-pack <pack> <manifest> (from an empty project)")
		quit(1)
		return
	hashes = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
	if not ProjectSettings.load_resource_pack(args[1], true):
		push_error("Cannot load exported pack")
		quit(1)
		return
	for path in hashes:
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != hashes[path]:
			push_error("Missing or changed legal/provenance file: " + path)
			quit(1)
			return
	print("PASS: %d legal and provenance files match the exported pack." % hashes.size())
	quit()
