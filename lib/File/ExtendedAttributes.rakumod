unit module File::ExtendedAttributes:auth<zef:avuserow>;

use NativeCall;
use Unix::errno;

class X::File::ExtendedAttributes::Unsupported is Exception {
    method message() {
        "Extended attributes are unsupported on this filesystem"
    }
}

sub handle-error {
    my $err = errno();
    die X::File::ExtendedAttributes::Unsupported.new if $err ~~ /'not supported'/;
    die $err;
}

sub listxattr(Str $path, CArray[uint8] $list, size_t $size) returns ssize_t is native {*}

our sub list-attributes(Str() $path) is export {
    my $size = listxattr($path, Any, 0);
    handle-error() if $size < 0;

    my $out = CArray[uint8].allocate($size);
    my $read = listxattr($path, $out, $size);
    handle-error() if $read < 0;

    # attributes are returned as a NULL separated list
    return Buf.new($out.list).decode.split("\0", :skip-empty);
}

sub getxattr(Str $path, Str $key, CArray[uint8] $value, size_t $size) returns size_t is native {*}

our sub get-attribute(Str() $path, Str $key, Bool :$bin) is export {
    my $size = getxattr($path, $key, Any, 0);
    handle-error() if $size < 0;

    my $out = CArray[uint8].allocate($size);
    my $read = getxattr($path, $key, $out, $size);
    handle-error() if $read < 0;

    my $data = Blob[uint8].new($out.list);
    return $data if $bin;
    return $data.decode;
}

sub setxattr_blob(Str $path, Str $key, CArray[uint8] $value, size_t $size, int32 $flags) returns int32 is native is symbol('setxattr') {*}
sub setxattr_str(Str $path, Str $key, Str $value, size_t $size, int32 $flags) returns int32 is native is symbol('setxattr') {*}

our proto set-attribute(Str() $path, Str $key, $value) is export {*}
multi sub set-attribute(Str() $path, Str $key, Str $value) {
    my $rv = setxattr_str($path, $key, $value, $value.encode.bytes, 0);
    handle-error() if $rv < 0;
}

multi sub set-attribute(Str() $path, Str $key, Blob[uint8] $value) {
    my $in = CArray[uint8].new: $value;
    my $rv = setxattr_blob($path, $key, $in, $value.elems, 0);
    handle-error() if $rv < 0;
}

sub removexattr(Str $path, Str $key) returns int32 is native {*}

our sub remove-attribute(Str() $path, Str $key) is export {
    my $rv = removexattr($path, $key);
    handle-error() if $rv < 0;
}

=begin pod

=head1 NAME

File::ExtendedAttributes - access extended attributes of files

=head1 SYNOPSIS

=begin code :lang<raku>

use File::ExtendedAttributes;

say list-attributes($path);

set-attribute($path, "user.test", "hello world");

say get-attribute($path, "user.test"); # as a str
say get-attribute($path, "user.test", :bin); # as a blob

remove-attribute($path, "user.test");

=end code

=head1 DESCRIPTION

File::ExtendedAttributes is a module to provide low-level access to extended attributes on Linux, sometimes known as C<xattr>s. These attributes are used for various metadata stored outside the file itself that can be interpreted by one or more applications.

This feature is well-supported on typical Linux filesystems, but may not be supported in all cases, especially with networked filesystems. Many filesystems generally impose size limits of a single filesystem block (often 1024, 2048, or 4096 bytes), so be frugal with the size of this metadata.

These attributes are conceptually key/value pairs. In Linux, the C<key> must begin with a namespace (typically C<user>) and a period, such as C<"user.test">. The value is an arbitrary string or blob.

=head1 FUNCTIONS

=head2 list-attributes($path)

Returns a list of attributes defined on the given path.

=head2 get-attribute($path, $key, :$bin)

Returns the value of the attribute if present. This value will be decoded as utf-8, unless the C<:bin> parameter is specified.

=head2 set-attribute($path, $key, $value)

Sets the specified attribute to the provided value. C<$value> may be a C<Str> or a C<Blob[uint8]>. If C<$value> is a string, it is encoded in utf-8 before being stored.

=head2 remove-attribute($path, $key)

Removes the given attribute. If the specified attribute does not exist, then an error is thrown (errno is C<ENODATA>).

=head1 ERRORS

If an error occurs, C<die> is called with the error message (provided by C<errno>). Error reporting may not be reliable if another thread can overwrite C<errno>.

=head1 SEE ALSO

The commands C<getfattr>/C<setfattr> and C<attr>

The C<xattr(7)> manpage

=head1 AUTHOR

Adrian Kreher <avuserow@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
