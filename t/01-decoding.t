use Test;
use Image::GIF;
plan *;

for dir 't/gifs' {
    my Image::GIF $gif;
    ok try {
        my $f = .open;
        $gif = decode-gif $f;
        $f.close;
    }, "GIF {.basename} decoded successfully";
}

# vim: ft=perl6
