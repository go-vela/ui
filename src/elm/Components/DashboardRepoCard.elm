{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.DashboardRepoCard exposing (view)

import Components.RecentBuilds
import Components.Svgs
import DateFormat.Relative
import FeatherIcons
import Html exposing (Html, a, br, div, header, li, p, section, span, text, ul)
import Html.Attributes
    exposing
        ( attribute
        , class
        )
import RemoteData
import Route.Path
import Shared
import Time
import Utils.Helpers as Util
import Vela


type alias Props =
    { card : Vela.DashboardRepoCard
    }


view : Shared.Model -> Props -> Html msg
view shared props =
    let
        cardProps =
            case List.head props.card.builds of
                Just build ->
                    { icon = Components.Svgs.recentBuildStatusToIcon build.status 0
                    , build = a [ Route.Path.href <| Route.Path.Org__Repo__Build_ { org = props.card.org, repo = props.card.name, build = String.fromInt build.number } ] [ text <| "#" ++ String.fromInt build.number ]
                    , event = build.event
                    , branch = build.branch
                    , sender = build.sender
                    , age =
                        let
                            buildStartedPosix =
                                Time.millisToPosix <| Util.secondsToMillis build.started
                        in
                        DateFormat.Relative.relativeTime shared.time <| buildStartedPosix
                    , duration = Util.formatRunTime shared.time build.started build.finished
                    , recentBuilds =
                        div
                            [ class "dashboard-recent-builds" ]
                            [ Components.RecentBuilds.view shared
                                { builds = RemoteData.succeed props.card.builds
                                , build = RemoteData.succeed build
                                , num = 5
                                , toPath = \_ -> Route.Path.Home_
                                , showTitle = False
                                }
                            ]
                    }

                Nothing ->
                    { icon = Components.Svgs.recentBuildStatusToIcon Vela.Pending 0
                    , build = span [] [ text "-" ]
                    , event = "-"
                    , branch = "-"
                    , age = "-"
                    , sender = "-"
                    , duration = "-"
                    , recentBuilds = div [ class "dashboard-no-builds" ] [ text "waiting for builds" ]
                    }
    in
    section [ class "card" ]
        [ header [ class "card-org-repo card-org-repo.padding-none" ]
            [ cardProps.icon
            , p []
                [ a
                    [ class "card-org"
                    , Route.Path.href <|
                        Route.Path.Org_
                            { org = props.card.org
                            }
                    ]
                    [ text props.card.org ]
                , br [] []
                , a
                    [ class "card-repo"
                    , Route.Path.href <|
                        Route.Path.Org__Repo_
                            { org = props.card.org
                            , repo = props.card.name
                            }
                    ]
                    [ text props.card.name ]
                ]
            ]
        , ul [ class "card-build-data" ] <|
            [ -- build link
              li [] [ FeatherIcons.cornerDownRight |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "go-to-build icon" ], cardProps.build ]

            -- event
            , li []
                [ FeatherIcons.send |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "event icon" ]
                , text <| cardProps.event
                ]

            -- branch
            , li []
                [ FeatherIcons.gitBranch |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "branch icon" ]
                , text <| cardProps.branch
                ]

            -- sender
            , li [] [ text <| cardProps.sender, FeatherIcons.user |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "build-sender icon" ] ]

            -- age
            , li [] [ text <| cardProps.age, FeatherIcons.calendar |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "time-started icon" ] ]

            -- duration
            , li []
                [ text <| cardProps.duration, FeatherIcons.clock |> FeatherIcons.withSize 20 |> FeatherIcons.toHtml [ attribute "aria-label" "duration icon" ] ]
            ]
        , cardProps.recentBuilds
        ]
