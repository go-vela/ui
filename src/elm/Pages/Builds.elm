{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Builds exposing (view)

import Html exposing (Html, div, h1, p, text)
import Html.Attributes exposing (class)
import Pages.Build exposing (viewPreview)
import RemoteData exposing (RemoteData(..))
import Time exposing (Posix)
import Util exposing (largeLoader)
import Vela exposing (BuildsModel)


{-| view : takes org and repo and renders build previews
-}
view : BuildsModel -> Posix -> String -> String -> Html msg
view buildsModel now org repo =
    let
        none =
            div []
                [ h1 []
                    [ text "No Builds Found"
                    ]
                , p []
                    [ text <|
                        "Builds sent to Vela will show up here."
                    ]
                ]
    in
    case buildsModel.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewPreview now org repo) builds

        RemoteData.Loading ->
            largeLoader

        RemoteData.NotAsked ->
            largeLoader

        RemoteData.Failure _ ->
            div [ Util.testAttribute "builds-error" ]
                [ p []
                    [ text <|
                        "There was an error fetching builds for this repository, please try again later!"
                    ]
                ]
