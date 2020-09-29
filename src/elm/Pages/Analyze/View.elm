{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Analyze.View exposing (viewAnalysis)

import Dict
import Dict.Extra
import Html
    exposing
        ( Html
        , a
        , div
        , span
        , text
        )
import Html.Attributes exposing (attribute, class)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import Pages.Analyze.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import SvgBuilder
import Vela
    exposing
        ( Build
        , Org
        , Repo
        , Step
        , Steps
        )



-- VIEW


event : Build -> Html Msg
event build =
    div [ class "trigger" ]
        [ div [] [ span [] [ text "event" ], span [] [ text build.event ] ]
        , div [] [ span [] [ text "branch" ], span [] [ text build.branch ] ]
        ]


pipeline : Build -> Steps -> Html Msg
pipeline build steps =
    let
        stages =
            steps
                |> Dict.Extra.groupBy .stage
                |> Dict.toList
                |> List.map
                    (\( stage, steps_ ) ->
                        div [ class "stage" ] <|
                            List.map viewStep steps_
                    )
    in
    stages
        |> div [ class "pipline" ]


{-| viewStep :
-}
viewStep : Step -> Html msg
viewStep step =
    let
        icon =
            SvgBuilder.recentBuildStatusToIcon step.status 0
    in
    div [ class "step" ]
        [ a
            [ class "recent-build-link"

            -- , Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
            -- , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
            ]
            [ icon
            ]
        ]


viewAnalysis : PartialModel a -> Org -> Repo -> Html Msg
viewAnalysis model org repo =
    case ( model.build, model.steps ) of
        ( RemoteData.Success build, RemoteData.Success steps ) ->
            div [ class "analysis" ]
                [ event build
                , pipeline build steps
                ]

        _ ->
            text ""
