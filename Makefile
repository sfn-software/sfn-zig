all: release

debug:
	zig build-exe -O Debug sfn.zig
release: release-safe
release-safe:
	zig build-exe -O ReleaseSafe sfn.zig
release-fast:
	zig build-exe -O ReleaseFast sfn.zig
release-small:
	zig build-exe -O ReleaseSmall sfn.zig

run:
	./sfn
