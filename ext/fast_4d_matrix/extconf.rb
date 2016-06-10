# Loads mkmf which is used to make makefiles for Ruby extensions
require 'mkmf'

# Give it a name
extension_name = 'fast_4d_matrix'
append_cflags('-std=c99')
append_cflags('-mtune=core2')
append_cflags('-Wno-declaration-after-statement')
append_cflags('-O3 -mfpmath=sse -msse2 -mavx')
append_ldflags('-lm')

# The destination
dir_config(extension_name)

# Do the work
create_makefile(extension_name)