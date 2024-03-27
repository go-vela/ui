{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Favicons exposing (Favicon, defaultFavicon, statusToFavicon, updateFavicon)

import Interop
import Json.Encode
import Url.Builder
import Vela


{-| Favicon : type alias for favicon path.
-}
type alias Favicon =
    String


{-| defaultFavicon : returns absolute path to default favicon
-}
defaultFavicon : String
defaultFavicon =
    Url.Builder.absolute [ "images", "favicon.ico" ] []


{-| updateFavicon : sets the browser tab favicon
-}
updateFavicon : Favicon -> Favicon -> ( Favicon, Cmd msg )
updateFavicon currentFavicon newFavicon =
    if currentFavicon /= newFavicon then
        ( newFavicon, Interop.setFavicon <| Json.Encode.string newFavicon )

    else
        ( currentFavicon, Cmd.none )


{-| statusToFavicon : takes build status and returns absolute path to the appropriate favicon
-}
statusToFavicon : Vela.Status -> Favicon
statusToFavicon status =
    let
        fileName =
            "favicon"
                ++ (case status of
                        Vela.Pending ->
                            "-pending"

                        Vela.PendingApproval ->
                            "-pending"

                        Vela.Running ->
                            "-running"

                        Vela.Success ->
                            "-success"

                        Vela.Failure ->
                            "-failure"

                        Vela.Killed ->
                            "-failure"

                        Vela.Canceled ->
                            "-canceled"

                        Vela.Error ->
                            "-failure"
                   )
                ++ ".ico"
    in
    Url.Builder.absolute [ "images", fileName ] []
