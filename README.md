[![Actions Status](https://github.com/avuserow/raku-file-extendedattributes/actions/workflows/test.yml/badge.svg)](https://github.com/avuserow/raku-file-extendedattributes/actions)

NAME
====

File::ExtendedAttributes - access extended attributes of files

SYNOPSIS
========

```raku
use File::ExtendedAttributes;

say list-attributes($path);

set-attribute($path, "user.test", "hello world");

say get-attribute($path, "user.test"); # as a str
say get-attribute($path, "user.test", :bin); # as a blob

remove-attribute($path, "user.test");
```

DESCRIPTION
===========

File::ExtendedAttributes is a module to provide low-level access to extended attributes on Linux, sometimes known as `xattr`s. These attributes are used for various metadata stored outside the file itself that can be interpreted by one or more applications.

This feature is well-supported on typical Linux filesystems, but may not be supported in all cases, especially with networked filesystems. Many filesystems generally impose size limits of a single filesystem block (often 1024, 2048, or 4096 bytes), so be frugal with the size of this metadata.

These attributes are conceptually key/value pairs. In Linux, the `key` must begin with a namespace (typically `user`) and a period, such as `"user.test"`. The value is an arbitrary string or blob.

FUNCTIONS
=========

list-attributes($path)
----------------------

Returns a list of attributes defined on the given path.

get-attribute($path, $key, :$bin)
---------------------------------

Returns the value of the attribute if present. This value will be decoded as utf-8, unless the `:bin` parameter is specified.

set-attribute($path, $key, $value)
----------------------------------

Sets the specified attribute to the provided value. `$value` may be a `Str` or a `Blob[uint8]`. If `$value` is a string, it is encoded in utf-8 before being stored.

remove-attribute($path, $key)
-----------------------------

Removes the given attribute. If the specified attribute does not exist, then an error is thrown (errno is `ENODATA`).

ERRORS
======

If an error occurs, a Failure is returned. If the error is `ENOTSUP`, then an Exception of `X::File::ExtendedAttributes::Unsupported` is thrown. If the error is `ENODATA`, then `X::File::ExtendedAttributes::NoData` is returned. Otherwise, an ad-hoc exception is thrown.

These are returned as Failures to enable the following approach in one-liners and shorter scripts:

```raku
my @values = @files.map({get-attribute($_, 'user.my-data') || ''});
```

If you do not check the returned value for truth, an exception will be raised instead.

SEE ALSO
========

The commands `getfattr`/`setfattr` and `attr`

The `xattr(7)` manpage

AUTHOR
======

Adrian Kreher <avuserow@gmail.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2022-2023 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

