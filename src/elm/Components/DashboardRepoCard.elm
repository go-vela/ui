{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.DashboardRepoCard exposing (view)

import Components.RecentBuilds
import Components.Svgs
import DateFormat.Relative
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , br
        , code
        , div
        , header
        , li
        , p
        , section
        , small
        , span
        , strong
        , text
        , ul
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , title
        )
import RemoteData
import Route.Path
import Shared
import Time
import Utils.Helpers as Util
import Vela


{-| Props : alias for an object representing properties for a dashboard repo card component.
-}
type alias Props =
    { card : Vela.DashboardRepoCard
    }


{-| view : renders a dashboard repo card component.
-}
view : Shared.Model -> Props -> Html msg
view shared props =
    let
        cardProps =
            case List.head props.card.builds of
                Just build ->
                    let
                        relativeAge =
                            build.started
                                |> Util.secondsToMillis
                                |> Time.millisToPosix
                                |> DateFormat.Relative.relativeTime shared.time

                        runtime =
                            Util.formatRunTime shared.time build.started build.finished
                    in
                    { icon = Components.Svgs.recentBuildStatusToIcon build.status 0
                    , build =
                        a
                            [ Route.Path.href <|
                                Route.Path.Org__Repo__Build_
                                    { org = props.card.org
                                    , repo = props.card.name
                                    , build = String.fromInt build.number
                                    }
                            ]
                            [ text <| "#" ++ String.fromInt build.number ]
                    , event = build.event
                    , branch = build.branch
                    , sender = build.sender
                    , age =
                        if build.started > 0 then
                            relativeAge

                        else
                            "-"
                    , duration = runtime
                    , recentBuilds =
                        div
                            [ class "dashboard-recent-builds" ]
                            [ Components.RecentBuilds.view shared
                                { builds = RemoteData.succeed props.card.builds
                                , build = RemoteData.succeed build
                                , num = 5
                                , toPath =
                                    \b ->
                                        Route.Path.Org__Repo__Build_
                                            { org = props.card.org
                                            , repo = props.card.name
                                            , build = b
                                            }
                                , showTitle = False
                                }
                            ]
                    }

                Nothing ->
                    let
                        dash =
                            "-"
                    in
                    { icon = Components.Svgs.recentBuildStatusToIcon Vela.Pending 0
                    , build = span [] [ text dash ]
                    , event = dash
                    , branch = dash
                    , age = dash
                    , sender = dash
                    , duration = "--:--"
                    , recentBuilds = div [ class "dashboard-recent-builds", class "-none" ] [ text "waiting for builds" ]
                    }
    in
    section [ class "card", Util.testAttribute "dashboard-card" ]
        [ header [ class "card-header" ]
            [ cardProps.icon
            , p []
                [ a
                    [ class "card-org"
                    , Route.Path.href <|
                        Route.Path.Org_
                            { org = props.card.org
                            }
                    ]
                    [ small [] [ text props.card.org ] ]
                , br [] []
                , a
                    [ class "card-repo -truncate"
                    , Route.Path.href <|
                        Route.Path.Org__Repo_
                            { org = props.card.org
                            , repo = props.card.name
                            }
                    ]
                    [ strong
                        [ Util.attrIf (String.length props.card.name > 25) (title props.card.name) ]
                        [ text props.card.name ]
                    ]
                ]
            ]
        , ul [ class "card-build-data" ] <|
            [ -- build link
              li []
                [ FeatherIcons.cornerDownRight
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "go-to-build icon" ]
                , cardProps.build
                ]

            -- event
            , li []
                [ FeatherIcons.send
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "event icon" ]
                , span [] [ text <| cardProps.event ]
                ]

            -- branch
            , li []
                [ FeatherIcons.gitBranch
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "branch icon" ]
                , span
                    [ Util.attrIf (String.length cardProps.branch > 15) (title cardProps.branch) ]
                    [ text <| cardProps.branch ]
                ]

            -- sender
            , li []
                [ span
                    [ Util.attrIf (String.length cardProps.sender > 15) (title cardProps.sender) ]
                    [ text <| cardProps.sender ]
                , FeatherIcons.user
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "build-sender icon" ]
                ]

            -- age
            , li []
                [ span [] [ text <| cardProps.age ]
                , FeatherIcons.calendar
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "time-started icon" ]
                ]

            -- duration
            , li []
                [ code [] [ text <| cardProps.duration ]
                , FeatherIcons.clock
                    |> FeatherIcons.withSize 20
                    |> FeatherIcons.toHtml [ attribute "aria-label" "duration icon" ]
                ]
            ]
        , cardProps.recentBuilds
        ]
