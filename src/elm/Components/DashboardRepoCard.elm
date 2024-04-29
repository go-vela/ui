{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.DashboardRepoCard exposing (view)

import Html exposing (Html, a, div, text)
import Html.Attributes
    exposing
        ( class
        )
import Route.Path
import Shared
import Utils.Helpers as Util
import Vela


type alias Props =
    { card : Vela.DashboardRepoCard
    }


view : Shared.Model -> Props -> Html msg
view shared props =
    div [ class "item" ]
        [ a
            [ Route.Path.href <|
                Route.Path.Org_
                    { org = props.card.org
                    }
            ]
            [ text props.card.org ]
        , a
            [ Route.Path.href <|
                Route.Path.Org__Repo_
                    { org = props.card.org
                    , repo = props.card.name
                    }
            ]
            [ text props.card.name ]
        , div [] <|
            case List.head props.card.builds of
                Just build ->
                    [ text <| "status: " ++ Vela.statusToString build.status
                    , text <| "build: " ++ String.fromInt build.number
                    , text <| "sender: " ++ build.sender
                    , text <| "branch: " ++ build.branch
                    , text <| "event: " ++ build.event
                    , text <| "started: " ++ Util.humanReadableDateWithDefault shared.zone build.started
                    , text <| "duration: " ++ Util.formatRunTime shared.time build.started build.finished
                    ]

                Nothing ->
                    [ text "No builds found" ]
        ]
