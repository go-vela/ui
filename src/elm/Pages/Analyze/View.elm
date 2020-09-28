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
        , div
        , span
        , text
        )
import Html.Attributes exposing (class)
import Http exposing (Error(..))
import Pages exposing (Page(..))
import Pages.Analyze.Model exposing (Msg(..), PartialModel)
import RemoteData exposing (RemoteData(..))
import Routes exposing (Route(..))
import Vela
    exposing
        ( Build
        , Org
        , Repo
        , Steps
        )



-- VIEW


event : Build -> Html Msg
event build =
    div [ class "analyze-event" ]
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
                        steps_ 
                            |> List.map (\step -> div [class "step"] [text stage])
                            |> div [ class "stage" ]
                    )

        -- |> List.map (\step -> (step.stage, step))
        -- |> Dict.fromList
        -- |> Dict.toList
        -- |> List.map (\(org, steps_) -> List.map (\s -> text "s") steps_)
    in
    stages
        |> div [ class "pipline" ]


viewAnalysis : PartialModel a -> Org -> Repo -> Html Msg
viewAnalysis model org repo =
    case ( model.build, model.steps ) of
        ( RemoteData.Success build, RemoteData.Success steps ) ->
            div []
                [ event build
                , pipeline build steps
                ]

        _ ->
            text ""
