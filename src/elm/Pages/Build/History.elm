module Pages.Build.History exposing (..)

import Html exposing (Html, a, div, em, li, p, span, text, ul)
import Html.Attributes exposing (attribute, class)
import Pages exposing (Page(..))
import RemoteData
import Routes
import SvgBuilder exposing (recentBuildStatusToIcon)
import Time exposing (Posix, Zone)
import Util
import Vela exposing (Build, Org, Repo, RepoModel)



-- RECENT BUILDS


{-| view : takes the 10 most recent builds and renders icons/links back to them as a widget at the top of the Build page
-}
view : Posix -> Zone -> Page -> Int -> RepoModel -> Html msg
view now timezone page limit rm =
    let
        org =
            rm.org

        repo =
            rm.name

        builds =
            rm.builds.builds

        buildNumber =
            case page of
                Pages.Build _ _ b _ ->
                    Maybe.withDefault -1 <| String.toInt b

                Pages.BuildServices _ _ b _ ->
                    Maybe.withDefault -1 <| String.toInt b

                _ ->
                    -1
    in
    case builds of
        RemoteData.Success blds ->
            if List.length blds > 0 then
                div [ class "build-history" ]
                    [ p [ class "build-history-title" ] [ text "Recent Builds" ]
                    , ul [ Util.testAttribute "build-history", class "previews" ] <|
                        List.indexedMap (viewRecentBuild now timezone page org repo buildNumber) <|
                            List.take limit blds
                    ]

            else
                text ""

        RemoteData.Loading ->
            div [ class "build-history" ] [ Util.smallLoader ]

        RemoteData.NotAsked ->
            div [ class "build-history" ] [ Util.smallLoader ]

        _ ->
            text ""


{-| viewRecentBuild : takes recent build and renders status and link to build as a small icon widget

    focusing or hovering the recent build icon will display a build info tooltip

-}
viewRecentBuild : Posix -> Zone -> Page -> Org -> Repo -> Int -> Int -> Build -> Html msg
viewRecentBuild now timezone page org repo buildNumber idx build =
    li [ class "recent-build" ]
        [ recentBuildLink page org repo buildNumber build idx
        , recentBuildTooltip now timezone build
        ]


{-| recentBuildLink : takes time info and build and renders line for redirecting to recent build

    focusing and hovering this element will display the tooltip

-}
recentBuildLink : Page -> Org -> Repo -> Int -> Build -> Int -> Html msg
recentBuildLink page org repo buildNumber build idx =
    let
        icon =
            recentBuildStatusToIcon build.status idx

        currentBuildClass =
            if buildNumber == build.number then
                class "-current"

            else if buildNumber > build.number then
                class "-older"

            else
                class ""
    in
    a
        [ class "recent-build-link"
        , Util.testAttribute <| "recent-build-link-" ++ String.fromInt buildNumber
        , currentBuildClass
        , case page of
            Pages.Build _ _ _ _ ->
                Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing

            Pages.BuildServices _ _ _ _ ->
                Routes.href <| Routes.BuildServices org repo (String.fromInt build.number) Nothing

            _ ->
                Routes.href <| Routes.Build org repo (String.fromInt build.number) Nothing
        , attribute "aria-label" <| "go to previous build number " ++ String.fromInt build.number
        ]
        [ icon
        ]


{-| recentBuildTooltip : takes time info and build and renders tooltip for viewing recent build info

    tooltip is visible when the recent build link is focused or hovered

-}
recentBuildTooltip : Posix -> Zone -> Build -> Html msg
recentBuildTooltip now timezone build =
    div [ class "recent-build-tooltip", Util.testAttribute "build-history-tooltip" ]
        [ ul [ class "info" ]
            [ li [ class "line" ]
                [ span [ class "number" ] [ text <| String.fromInt build.number ]
                , em [] [ text build.event ]
                ]
            , viewTooltipField "started:" <| Util.dateToHumanReadable timezone build.started
            , viewTooltipField "finished:" <| Util.dateToHumanReadable timezone build.finished
            , viewTooltipField "duration:" <| Util.formatRunTime now build.started build.finished
            , viewTooltipField "worker:" build.host
            , viewTooltipField "commit:" <| Util.trimCommitHash build.commit
            , viewTooltipField "branch:" build.branch
            ]
        ]


{-| viewTooltipField : takes build field key and value, renders field in the tooltip
-}
viewTooltipField : String -> String -> Html msg
viewTooltipField key value =
    li [ class "line" ] [ span [] [ text key ], text value ]
