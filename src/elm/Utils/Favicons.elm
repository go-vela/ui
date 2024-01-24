{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Favicons exposing (..)

import Interop
import Json.Encode
import RemoteData exposing (WebData)
import Url.Builder
import Vela



-- STATUS FAVICONS


type alias Favicon =
    String


{-| defaultFavicon : returns absolute path to default favicon
-}
defaultFavicon : String
defaultFavicon =
    Url.Builder.absolute [ "images", "favicon.ico" ] []


{-| setDefaultFavicon : restores the favicon to the default
-}
setDefaultFavicon : Favicon -> ( Favicon, Cmd msg )
setDefaultFavicon currentFavicon =
    if currentFavicon /= defaultFavicon then
        ( defaultFavicon, Interop.setFavicon <| Json.Encode.string defaultFavicon )

    else
        ( currentFavicon, Cmd.none )


{-| refreshBuildFavicon : updates the favicon, to be used on pages with status updates
-}
refreshBuildFavicon : Favicon -> WebData Vela.Build -> ( Favicon, Cmd msg )
refreshBuildFavicon currentFavicon build =
    case build of
        RemoteData.Success b ->
            let
                newFavicon =
                    statusToFavicon b.status
            in
            if currentFavicon /= newFavicon then
                ( newFavicon, Interop.setFavicon <| Json.Encode.string newFavicon )

            else
                ( currentFavicon, Cmd.none )

        _ ->
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
