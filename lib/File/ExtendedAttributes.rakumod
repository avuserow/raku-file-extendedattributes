unit module File::ExtendedAttributes:auth<zef:avuserow>;

use NativeCall;
use Unix::errno;

class X::File::ExtendedAttributes::Unsupported is Exception {
    has $.path = '';
    has $.key = '';

    method message() {
        my $msg = "Extended attributes are unsupported on the filesystem of '$!path'";
        if $!key && $!key.starts-with('user.') {
            $msg ~= ": key '$!key'";
        } elsif $!key {
            $msg ~= ": key '$!key' may need to start with the proper namespace, typically 'user.'";
        }
        $msg;
    }
}

class X::File::ExtendedAttributes::NoData is Exception {
    has $.path = '';
    has $.key = '';

    method message() {
        "Path '$!path' has no data for extended attribute key '$!key'";
    }
}


sub handle-error(:$path, :$key) {
    my $err = errno();
    fail X::File::ExtendedAttributes::Unsupported.new(:$path, :$key) if $err ~~ /'not supported'/;

    # TODO: Unix::errno gets this description wrong, look up this value by number
    # See https://github.com/lizmat/Unix-errno/issues/1
    fail X::File::ExtendedAttributes::NoData.new(:$path, :$key) if +$err == 61;

    fail $err.gist;
}

sub listxattr(Str $path, CArray[uint8] $list, size_t $size) returns ssize_t is native {*}

our sub list-attributes(Str() $path) is export {
    my $size = listxattr($path, Any, 0);
    fail handle-error(:$path) if $size < 0;

    my $out = CArray[uint8].allocate($size);
    my $read = listxattr($path, $out, $size);
    fail handle-error(:$path) if $read < 0;

    # attributes are returned as a NULL separated list
    return Buf.new($out.list).decode.split("\0", :skip-empty);
}

sub getxattr(Str $path, Str $key, CArray[uint8] $value, size_t $size) returns size_t is native {*}

our sub get-attribute(Str() $path, Str $key, Bool :$bin) is export {
    my $size = getxattr($path, $key, Any, 0);
    fail handle-error(:$path, :$key) if $size < 0;

    my $out = CArray[uint8].allocate($size);
    my $read = getxattr($path, $key, $out, $size);
    fail handle-error(:$path, :$key) if $read < 0;

    my $data = Blob[uint8].new($out.list);
    return $data if $bin;
    return $data.decode;
}

sub setxattr_blob(Str $path, Str $key, CArray[uint8] $value, size_t $size, int32 $flags) returns int32 is native is symbol('setxattr') {*}
sub setxattr_str(Str $path, Str $key, Str $value, size_t $size, int32 $flags) returns int32 is native is symbol('setxattr') {*}

our proto set-attribute(Str() $path, Str $key, $value) is export {*}
multi sub set-attribute(Str() $path, Str $key, Str $value) {
    my $rv = setxattr_str($path, $key, $value, $value.encode.bytes, 0);
    fail handle-error(:$path, :$key) if $rv < 0;
}

multi sub set-attribute(Str() $path, Str $key, Blob[uint8] $value) {
    my $in = CArray[uint8].new: $value;
    my $rv = setxattr_blob($path, $key, $in, $value.elems, 0);
    fail handle-error(:$path, :$key) if $rv < 0;
}

sub removexattr(Str $path, Str $key) returns int32 is native {*}

our sub remove-attribute(Str() $path, Str $key) is export {
    my $rv = removexattr($path, $key);
    fail handle-error(:$path, :$key) if $rv < 0;
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

If an error occurs, a Failure is returned. If the error is C<ENOTSUP>, then an Exception of C<X::File::ExtendedAttributes::Unsupported> is thrown. If the error is C<ENODATA>, then C<X::File::ExtendedAttributes::NoData> is returned. Otherwise, an ad-hoc exception is thrown.

These are returned as Failures to enable the following approach in one-liners and shorter scripts:

=begin code :lang<raku>

my @values = @files.map({get-attribute($_, 'user.my-data') || ''});

=end code

If you do not check the returned value for truth, an exception will be raised instead.

=head1 SEE ALSO

The commands C<getfattr>/C<setfattr> and C<attr>

The C<xattr(7)> manpage

=head1 AUTHOR

Adrian Kreher <avuserow@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2022-2023 Adrian Kreher

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
