class X::Image::GIF::Malformed is Exception {
    my $.pos;
    method message {
        $.pos ?? "Malformed GIF near byte $.pos" !! "Malformed GIF"
    }
}
class X::Image::GIF::Unknown is Exception {
    my $.version;
    method message { "Unknown GIF version '$.version'" }
}
