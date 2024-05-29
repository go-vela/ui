{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.RecentBuilds exposing (view)


import Components.Loading
import Components.Svgs
import Html exposing (Html, a, div, em, li, p, span, text, ul)
import Html.Attributes exposing (attribute, class)
import RemoteData exposing (WebData)
import Route.Path
import Shared
import Utils.Helpers as Util
import Vela



--TYPES


{-| Props : alias for an object representing properties for the recent builds component.
-}
type alias Props =
    { builds : WebData (List Vela.Build)
    , build : WebData Vela.Build
    , num : Int
    , toPath : String -> Route.Path.Path
    , showTitle : Bool
    }



-- VIEW


{-| view : renders recent builds history.
-}
view : Shared.Model -> Props -> Html msg
view shared props =
    let
        viewTitle =
            if props.showTitle then
                p [ class "build-history-title" ] [ text "Recent Builds" ]

            else
                text ""
    in
    case props.builds of
        RemoteData.Success builds ->
            if List.length builds > 0 then
                div [ class "build-history" ]
                    [ viewTitle
                    , ul [ Util.testAttribute "build-history", class "previews" ] <|
                        List.indexedMap (viewRecentBuild shared props) <|
                            List.take props.num builds
                    ]

            else
                text ""

        _ ->
            Components.Loading.viewSmallLoader


{-| viewRecentBuild : takes recent build and renders status and link to build as a small icon widget.

    focusing or hovering the recent build icon will display a build info tooltip

-}
viewRecentBuild : Shared.Model -> Props -> Int -> Vela.Build -> Html msg
viewRecentBuild shared props idx build =
    li [ class "recent-build" ]
        [ recentBuildLink shared props idx build
        , recentBuildTooltip shared props build
        ]


{-| recentBuildLink : takes time info and build and renders line for redirecting to recent build.

    focusing and hovering this element will display the tooltip

-}
recentBuildLink : Shared.Model -> Props -> Int -> Vela.Build -> Html msg
recentBuildLink shared props idx build =
    let
        icon =
            Components.Svgs.recentBuildStatusToIcon build.status idx

        currentBuildNumber =
            RemoteData.unwrap -1 .number props.build

        currentBuildClass =
            if currentBuildNumber == build.number then
                class "-current"

            else
                class ""
    in
    a
        [ class "recent-build-link"
        , Util.testAttribute <| "recent-build-link-" ++ String.fromInt build.number
        , currentBuildClass
        , Route.Path.href <|
            props.toPath (String.fromInt build.number)
        , attribute "aria-label" <| "go to recent build number " ++ String.fromInt build.number
        ]
        [ icon
        ]


{-| recentBuildTooltip : takes time info and build and renders tooltip for viewing recent build info.

    tooltip is visible when the recent build link is focused or hovered

-}
recentBuildTooltip : Shared.Model -> Props -> Vela.Build -> Html msg
recentBuildTooltip shared props build =
    div [ class "recent-build-tooltip", Util.testAttribute "build-history-tooltip" ]
        [ ul [ class "info" ]
            [ li [ class "line" ]
                [ span [ class "number" ] [ text <| String.fromInt build.number ]
                , em [] [ text build.event ]
                ]
            , buildInfo build
            , viewTooltipField "started:" <| Util.humanReadableDateWithDefault shared.zone build.started
            , viewTooltipField "finished:" <| Util.humanReadableDateWithDefault shared.zone build.finished
            , viewTooltipField "duration:" <| Util.formatRunTime shared.time build.started build.finished
            , viewTooltipField "worker:" build.host
            , viewTooltipField "author:" build.author
            , viewTooltipField "commit:" <| Util.trimCommitHash build.commit
            , viewTooltipField "branch:" build.branch
            ]
        ]


{-| buildInfo : displays and populates ref info for pr and tag events.
-}
buildInfo : Vela.Build -> Html msg
buildInfo build =
    case build.event of
        "pull_request" ->
            viewTooltipField "PR" ("#" ++ Util.getNameFromRef build.ref ++ " " ++ build.message)

        "tag" ->
            viewTooltipField "Tag" (Util.getNameFromRef build.ref)

        _ ->
            viewTooltipField "" ""


{-| viewTooltipField : renders the HTML for a line item in the tool tip component.
-}
viewTooltipField : String -> String -> Html msg
viewTooltipField key value =
    if String.isEmpty value then
        text ""

    else
        li [ class "line" ]
            [ span [] [ text key ]
            , span [] [ text value ]
            ]
