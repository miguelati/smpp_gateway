# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# Add files and commands to this file, like the example:
#   watch(%r{file/path}) { `command(s)` }
#
guard :shell do
  watch(/lib_source\/(.*).rb/) {|m|
    `rbx compile -s '^lib_source:lib' #{m[0]}`
  }
end
