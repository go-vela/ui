{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Logs exposing (view)

import Ansi.Log
import Array
import Browser.Dom exposing (focus)
import Components.Loading
import FeatherIcons
import Html exposing (Html, a, button, code, div, span, table, td, text, tr)
import Html.Attributes exposing (attribute, class, href, id)
import Html.Events exposing (onClick)
import Html.Lazy
import RemoteData exposing (WebData)
import Shared
import Url
import Utils.Ansi
import Utils.Focus as Focus
import Utils.Helpers as Util
import Utils.Logs as Logs
import Vela



-- TYPES


type alias Msgs msg =
    { pushUrlHash : { hash : String } -> msg
    , focusOn : { target : String } -> msg
    , download : { filename : String, content : String, map : String -> String } -> msg
    , follow : { number : Int } -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , shift : Bool
    , log : WebData Vela.Log
    , org : String
    , repo : String
    , buildNumber : String
    , resourceType : String
    , resourceNumber : String
    , focus : Focus.Focus
    , follow : Int
    }


type alias LogLine msg =
    { view : Html msg
    }



-- VIEW


view : Shared.Model -> Props msg -> Html msg
view shared props =
    case props.log of
        RemoteData.Success log ->
            viewLogLines props log

        RemoteData.Failure _ ->
            code [ Util.testAttribute "logs-error" ] [ text "error fetching logs" ]

        _ ->
            div [ class "message" ]
                [ Components.Loading.viewSmallLoaderWithText "loading..." ]


{-| viewLogLines : takes number linefocus log and clickAction shiftDown and renders logs for a build resource
-}
viewLogLines : Props msg -> Vela.Log -> Html msg
viewLogLines props log =
    let
        -- deconstructing props here to make lazy rendering work properly
        lines =
            Html.Lazy.lazy6
                viewLines
                props.msgs.pushUrlHash
                props.resourceType
                props.resourceNumber
                props.shift
                props.focus
                log.decodedLogs
    in
    div
        [ class "logs"
        , Util.testAttribute <| "logs-" ++ props.resourceNumber
        ]
        [ viewLogsHeader props log
        , viewLogsSidebar props
        , lines
        ]


{-| viewLines : takes number, line focus information and click action and renders logs
-}
viewLines : ({ hash : String } -> msg) -> String -> String -> Bool -> Focus.Focus -> String -> Html msg
viewLines pushUrlHashMsg resourceType resourceNumber shift focus log =
    let
        lines =
            log
                |> processLogLines
                |> List.indexedMap
                    (\idx logLine ->
                        Just <|
                            viewLine
                                pushUrlHashMsg
                                resourceType
                                resourceNumber
                                shift
                                focus
                                logLine
                                (idx + 1)
                    )

        logs =
            lines
                |> List.filterMap identity

        topTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <| Logs.topTrackerFocusId resourceNumber
                    , Util.testAttribute <| "top-log-tracker-" ++ resourceNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ id <| Logs.bottomTrackerFocusId resourceNumber
                    , Util.testAttribute <| "bottom-log-tracker-" ++ resourceNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]
    in
    table [ class "logs-table", class "scrollable" ] <|
        topTracker
            :: logs
            ++ [ bottomTracker ]


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : ({ hash : String } -> msg) -> String -> String -> Bool -> Focus.Focus -> LogLine msg -> Int -> Html msg
viewLine pushUrlHashMsg resourceType resourceNumber shift focus logLine lineNumber =
    tr
        [ Html.Attributes.id <|
            resourceNumber
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ div
            [ class "wrapper"
            , Util.testAttribute <| String.join "-" [ "log", "line", resourceType, resourceNumber, String.fromInt lineNumber ]
            , class <| Focus.lineRangeStyles (String.toInt resourceNumber) lineNumber focus
            ]
            [ td []
                [ button
                    [ Util.onClickPreventDefault <|
                        pushUrlHashMsg
                            { hash =
                                Focus.toString <| Focus.updateLineRange shift (String.toInt resourceNumber) lineNumber focus
                            }
                    , Util.testAttribute <| String.join "-" [ "log", "line", "num", resourceType, resourceNumber, String.fromInt lineNumber ]
                    , Focus.toAttr
                        { group = String.toInt resourceNumber
                        , a = Just lineNumber
                        , b = Nothing
                        }
                    , class "line-number"
                    , class "button"
                    , class "-link"
                    , attribute "aria-label" <| "focus " ++ resourceType ++ " " ++ resourceNumber
                    ]
                    [ span [] [ text <| String.fromInt lineNumber ] ]
                ]
            , td [ class "break-text", class "overflow-auto" ]
                [ code [ Util.testAttribute <| String.join "-" [ "log", "data", resourceType, resourceNumber, String.fromInt lineNumber ] ]
                    [ logLine.view
                    ]
                ]
            ]
        ]


{-| processLogLines : takes a log as string, splits it by newline, and processes it into a model that can render custom elements like timestamps and links
-}
processLogLines : String -> List (LogLine msg)
processLogLines log =
    log
        |> String.split "\n"
        |> List.map
            (\log_ ->
                let
                    -- first we convert the individual log line into an Ansi.Log.Model
                    -- this lets us preserve the original ANSI style while applying our own processing
                    -- we use List.head to ignore extra empty lines generated by Ansi.Log.update, since we already split by newline
                    ansiLogLine =
                        List.head <| Array.toList <| .lines <| Ansi.Log.update log_ Utils.Ansi.defaultAnsiLogModel
                in
                -- next we take the decoded log line, run custom processing like link parsing, then render it to Html
                case ansiLogLine of
                    Just logLine ->
                        -- pack the log line into a struct to make it more flexible when rendering later
                        -- this is particularly useful for adding toggleable features like timestamps
                        -- we will most likely need to extend this to accept user preferences
                        -- for example, a user may choose to not render links or timestamps
                        -- per chunk render processing happens in processLogLine
                        processLogLine logLine

                    Nothing ->
                        LogLine (text "")
            )


{-| processLogLine : takes Ansi.Log.Line and renders it into Html after parsing and processing custom rendering rules
-}
processLogLine : Ansi.Log.Line -> LogLine msg
processLogLine ansiLogLine =
    let
        -- per-log line processing goes here
        ( chunks, _ ) =
            ansiLogLine

        -- a single div is rendered containing a styled span for each ansi "chunk"
        view_ =
            div [] <|
                List.foldl
                    (\c l ->
                        -- potential here to read metadata from "chunks" and store in LogLine
                        viewChunk c :: l
                    )
                    [ text "\n" ]
                    chunks
    in
    LogLine view_


{-| viewChunk : takes Ansi.Log.Chunk and renders it into Html with ANSI styling
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been modified to allow custom processing
-}
viewChunk : Ansi.Log.Chunk -> Html msg
viewChunk chunk =
    chunk
        -- per-chunk processing goes here
        |> viewLogLinks
        |> viewAnsi chunk


{-| viewAnsi : takes Ansi.Log.Chunk and Html children and renders wraps them with ANSI styling
-}
viewAnsi : Ansi.Log.Chunk -> List (Html msg) -> Html msg
viewAnsi chunk children =
    span (Utils.Ansi.styleAttributesAnsi chunk.style) children


{-| viewLogLinks : takes Ansi.Log.Chunk and performs additional processing to parse links
-}
viewLogLinks : Ansi.Log.Chunk -> List (Html msg)
viewLogLinks chunk =
    let
        -- list of string escape characters that delimit links.
        -- for example "<https://github.com"> should be split from the quotes, even though " is a valid URL character (see: see: <https://www.rfc-editor.org/rfc/rfc3986#section-2>)
        linkEscapeCharacters =
            [ "'", " ", "\"", "\t", "\n" ]

        -- its possible this will split a "valid" link containing quote characters, but its a willing risk
        splitIntersperseConcat : String -> List String -> List String
        splitIntersperseConcat sep list =
            list
                |> List.concatMap
                    (\x ->
                        x
                            |> String.split sep
                            |> List.intersperse sep
                    )

        -- split the "line" by escape characters
        split =
            List.foldl splitIntersperseConcat [ chunk.text ] linkEscapeCharacters
    in
    -- "process" each "split chunk" and check for link
    -- for example, this accounts for multiple links contained in a single ANSI background color "chunk"
    List.map
        (\chunk_ ->
            case Url.fromString chunk_ of
                Just link ->
                    viewLogLink link chunk_

                Nothing ->
                    text chunk_
        )
        split


{-| viewLogLink : takes a url and label and renders a link
-}
viewLogLink : Url.Url -> String -> Html msg
viewLogLink link txt =
    -- use toString in href to make the link safe
    a [ Util.testAttribute "log-line-link", href <| Url.toString link ] [ text txt ]


{-| viewLogsHeader : takes number, filename and decoded log and renders logs header
-}
viewLogsHeader : Props msg -> Vela.Log -> Html msg
viewLogsHeader props log =
    div
        [ class "logs-header"
        , class "buttons"
        , Util.testAttribute <| "logs-header-actions-" ++ props.resourceNumber
        ]
        [ viewDownloadButton props log
        ]


{-| viewLogsSidebar : takes number/following and renders the logs sidebar
-}
viewLogsSidebar : Props msg -> Html msg
viewLogsSidebar props =
    div [ class "logs-sidebar" ]
        [ div [ class "inner-container" ]
            [ div
                [ class "actions"
                , Util.testAttribute <| "logs-sidebar-actions-" ++ props.resourceNumber
                ]
                [ viewJumpToTopButton props
                , viewJumpToBottomButton props
                , viewFollowButton props
                ]
            ]
        ]


{-| viewJumpToBottomButton : renders action button for jumping to the bottom of a log
-}
viewJumpToBottomButton : Props msg -> Html msg
viewJumpToBottomButton props =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to bottom"
        , Util.testAttribute <| "jump-to-bottom-" ++ props.resourceNumber
        , onClick <| props.msgs.focusOn { target = Logs.bottomTrackerFocusId props.resourceNumber }
        , attribute "aria-label" <| "jump to bottom of logs for " ++ props.resourceType ++ " " ++ props.resourceNumber
        ]
        [ FeatherIcons.arrowDown |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| viewJumpToTopButton : renders action button for jumping to the top of a log
-}
viewJumpToTopButton : Props msg -> Html msg
viewJumpToTopButton props =
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" "jump to top"
        , Util.testAttribute <| "jump-to-top-" ++ props.resourceNumber
        , onClick <| props.msgs.focusOn { target = Logs.topTrackerFocusId props.resourceNumber }
        , attribute "aria-label" <| "jump to top of logs for " ++ props.resourceType ++ " " ++ props.resourceNumber
        ]
        [ FeatherIcons.arrowUp |> FeatherIcons.toHtml [ attribute "role" "img" ] ]


{-| viewDownloadButton : renders action button for downloading a log
-}
viewDownloadButton : Props msg -> Vela.Log -> Html msg
viewDownloadButton props log =
    let
        logEmpty =
            log.size == 0

        fileName =
            String.join "-" [ props.org, props.repo, props.buildNumber, props.resourceType, props.resourceNumber ]
                ++ ".txt"
    in
    button
        [ class "button"
        , class "-link"
        , Html.Attributes.disabled logEmpty
        , Util.attrIf logEmpty <| class "-hidden"
        , Util.attrIf logEmpty <| Util.ariaHidden
        , Util.testAttribute <| "download-logs-" ++ props.resourceNumber
        , onClick <| props.msgs.download { filename = fileName, content = log.rawData, map = Util.base64Decode }
        , attribute "aria-label" <| "download logs for " ++ props.resourceType ++ " " ++ props.resourceNumber
        ]
        [ text <| "download " ++ props.resourceType ++ " logs" ]


{-| viewFollowButton : renders button for following logs
-}
viewFollowButton : Props msg -> Html msg
viewFollowButton props =
    let
        num =
            Maybe.withDefault 0 <| String.toInt props.resourceNumber

        following =
            props.follow

        ( tooltip, icon, toFollow ) =
            if following == 0 then
                ( "start following " ++ props.resourceType ++ " logs", FeatherIcons.play, num )

            else if following == num then
                ( "stop following " ++ props.resourceType ++ " logs", FeatherIcons.pause, 0 )

            else
                ( "start following " ++ props.resourceType ++ " logs", FeatherIcons.play, num )
    in
    button
        [ class "button"
        , class "-icon"
        , class "tooltip-left"
        , attribute "data-tooltip" tooltip
        , Util.testAttribute <| "follow-logs-" ++ props.resourceNumber
        , onClick <| props.msgs.follow { number = toFollow }
        , attribute "aria-label" <| tooltip ++ " for " ++ props.resourceType ++ " " ++ props.resourceNumber
        ]
        [ icon |> FeatherIcons.toHtml [ attribute "role" "img", attribute "aria-label" "show build actions" ] ]
