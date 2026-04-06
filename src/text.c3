module c3po;

macro @starts_with($s, $needle) {
  $if !$defined($s[$needle.len - 1]):
    return false;
  $endif

  $foreach $i, $c : $needle:
    $if $defined($s[$i]) &&& $s[$i] != $c:
      return false;
    $endif
  $endforeach
  return true;
}

macro @trim_start($s) {
  $foreach $i, $c : $s:
    $if $s[$i] != ' ':
      return $s[$i..];
    $endif
  $endforeach
}
macro @trim_end($s) {
  $if $s == " ":
    return "";
  $endif

  $for var $i = $s.len - 1; $i > 0; $i-- :
    $if $s[$i] != ' ':
      return $s[..$i];
    $endif
  $endfor
}

macro @trim($s) {
  return @trim_end(@trim_start($s));
}


macro @str_replace($s, $pattern, $replace) {
  var $result = "";
  $for var $i = 0; $i < $s.len; $i++:
    $if @starts_with($s[$i..], $pattern):
      $result +++= $replace;
      $i += $pattern.len - 1;
    $else
      $result +++= $s[$i];
    $endif
  $endfor

  return $result;
}


macro String @textify($format, ...) {
  $foreach $color : Ansi.names:
    $format = @str_replace($format, "%{" +++ $color +++ "}", Ansi.$eval($color));
  $endforeach

  return string::tformat($format +++ Ansi.RESET, $vasplat);
}
