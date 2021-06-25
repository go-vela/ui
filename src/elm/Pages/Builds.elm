{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Builds exposing (view)

import Errors exposing (viewResourceError)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , em
        , h1
        , li
        , ol
        , p
        , text
        )
import Html.Attributes exposing (class, href)
import Pages.Build.View exposing (viewPreview)
import RemoteData exposing (RemoteData(..))
import Routes
import Svg.Attributes
import Time exposing (Posix, Zone)
import Util exposing (largeLoader)
import Vela exposing (BuildsModel, Event, Org, Repo)


{-| view : takes org and repo and renders build previews
-}
view : BuildsModel -> Posix -> Zone -> Org -> Repo -> Maybe Event -> Html msg
view buildsModel now zone org repo maybeEvent =
    let
        settingsLink : String
        settingsLink =
            "/" ++ String.join "/" [ org, repo ] ++ "/settings"
        none : Html msg
        none =
            case maybeEvent of
                Nothing ->
                    div []
                        [ h1 [] [ text "Your repository has been enabled!" ]
                        , p [] [ text "Builds will show up here once you have:" ]
                        , ol [ class "list" ]
                            [ li []
                                [ text "A "
                                , code [] [ text ".vela.yml" ]
                                , text " file that describes your build pipeline in the root of your repository."
                                , br [] []
                                , a [ href "https://go-vela.github.io/docs/usage/" ] [ text "Review the documentation" ]
                                , text " for help or "
                                , a [ href "https://go-vela.github.io/docs/usage/examples/" ] [ text "check some of the pipeline examples" ]
                                , text "."
                                ]
                            , li []
                                [ text "Trigger one of the "
                                , a [ href settingsLink ] [ text "configured webhook events" ]
                                , text " by performing the respective action via "
                                , em [] [ text "Git" ]
                                , text "."
                                ]
                            ]
                        , p [] [ text "Happy building!" ]
                        ]

                Just event ->
                    div []
                        [ h1 [] [ text <| "No builds for \"" ++ event ++ "\" event found." ] ]
    in
    case buildsModel.builds of
        RemoteData.Success builds ->
            if List.length builds == 0 then
                none

            else
                div [ class "builds", Util.testAttribute "builds" ] <| List.map (viewPreview now zone org repo) builds

        RemoteData.Loading ->
            largeLoader

        RemoteData.NotAsked ->
            largeLoader

        RemoteData.Failure _ ->
            viewResourceError { resourceLabel = "builds for this repository", testLabel = "builds" }
