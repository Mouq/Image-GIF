use Test;
use Image::GIF;
plan *;

for dir 't/gifs' {
    ok try {
        my $f = .open;
        decode-gif $f;
        $f.close;
    }, "GIF {.basename} decoded successfully";
}

# vim: ft=perl6
