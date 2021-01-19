
module Scroll exposing (..)

import Json.Decode as Decode
import Html.Events
type alias ScrollInfo =
    { scrollHeight : Float
    , scrollTop : Float
    , offsetHeight : Float
    }

onScroll msg =
    Html.Events.on "scroll" ( Decode.map msg scrollInfoDecoder)


scrollInfoDecoder =
    Decode.map3 ScrollInfo
        ( Decode.at [ "target", "scrollHeight" ]  Decode.float)
        ( Decode.at [ "target", "scrollTop" ]  Decode.float)
        ( Decode.at [ "target", "offsetHeight" ]  Decode.float)


