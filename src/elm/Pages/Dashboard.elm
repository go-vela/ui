module Pages.Dashboard exposing (view)

import Debug
import Html exposing (Html, div, h2, text)
import RemoteData exposing (RemoteData(..), WebData)
import Util
import Vela exposing (Dashboard)


view : WebData Dashboard -> String -> Html msg
view d id =
    case d of
        Success d_ ->
            let
                _ =
                    Debug.log "dashboard" d_
            in
            div []
                [ h2 [] [ text <| d_.dashboard.name ++ "/" ++ id ]
                ]

        Loading ->
            div []
                [ Util.largeLoader
                ]

        NotAsked ->
            div [] []

        Failure _ ->
            div [] []
