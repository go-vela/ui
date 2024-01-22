module Components.Logs exposing (safeDecodeLogData, view)

import Ansi
import Ansi.Log
import Array
import FeatherIcons
import Html exposing (Html, a, button, code, div, small, span, table, td, text, tr)
import Html.Attributes exposing (attribute, class, classList, href, id, style)
import Html.Events exposing (onClick)
import RemoteData exposing (WebData)
import Shared
import Url
import Utils.Focus as Focus
import Utils.Helpers as Util
import Vela


type alias Msgs msg =
    { focusLine : String -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , log : WebData Vela.Log
    , org : String
    , repo : String
    , buildNumber : String
    , resourceNumber : String
    , resourceType : String
    , lineFocus : Maybe LogFocus
    }


type alias LogLine msg =
    { view : Html msg
    }


type alias LogFocus =
    ( Maybe Int, Maybe Int )


view : Shared.Model -> Props msg -> Html msg
view shared props =
    case props.log of
        RemoteData.Success log ->
            viewLogLines shared props log

        RemoteData.Failure _ ->
            code [ Util.testAttribute "logs-error" ] [ text "error fetching logs" ]

        _ ->
            div [ class "message" ]
                [ Util.smallLoaderWithText "loading..." ]



-- LOGS


{-| viewLogLines : takes number linefocus log and clickAction shiftDown and renders logs for a build resource
-}
viewLogLines : Shared.Model -> Props msg -> Vela.Log -> Html msg
viewLogLines shared props log =
    div
        [ class "logs"
        , Util.testAttribute <| "logs-" ++ props.resourceNumber
        ]
    <|
        let
            fileName =
                String.join "-" [ props.org, props.repo, props.buildNumber, props.resourceType, props.resourceNumber ]

            ( lines, numLines ) =
                viewLines shared props log
        in
        [ logsHeader props fileName log
        , logsSidebar props numLines
        , lines
        ]


{-| viewLines : takes number, line focus information and click action and renders logs
-}
viewLines : Shared.Model -> Props msg -> Vela.Log -> ( Html msg, Int )
viewLines shared props log =
    let
        lines =
            log.decodedLogs
                -- this is where link parsing happens
                |> processLogLines
                |> List.indexedMap
                    (\idx logLine ->
                        Just <|
                            viewLine
                                shared
                                props
                                logLine
                                (idx + 1)
                    )

        logs =
            lines
                |> List.filterMap identity

        topTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ --     id <|
                      --     topTrackerFocusId resourceType resourceID
                      -- ,
                      Util.testAttribute <| "top-log-tracker-" ++ props.resourceNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]

        bottomTracker =
            tr [ class "line", class "tracker" ]
                [ a
                    [ --     id <|
                      --     bottomTrackerFocusId props.resourceType props.resourceID
                      -- ,
                      Util.testAttribute <| "bottom-log-tracker-" ++ props.resourceNumber
                    , Html.Attributes.tabindex -1
                    ]
                    []
                ]
    in
    ( table [ class "logs-table", class "scrollable" ] <|
        topTracker
            :: logs
            ++ [ bottomTracker ]
    , List.length lines
    )


{-| viewLine : takes log line and focus information and renders line number button and log
-}
viewLine : Shared.Model -> Props msg -> LogLine msg -> Int -> Html msg
viewLine shared props logLine lineNumber =
    tr
        [ Html.Attributes.id <|
            props.resourceNumber
                ++ ":"
                ++ String.fromInt lineNumber
        , class "line"
        ]
        [ div
            [ class "wrapper"
            , Util.testAttribute <| String.join "-" [ "log", "line", props.resourceType, props.resourceNumber, String.fromInt lineNumber ]
            , class <| Focus.lineFocusStyles props.lineFocus lineNumber
            ]
            [ td []
                [ lineFocusButton shared props lineNumber
                ]
            , td [ class "break-text", class "overflow-auto" ]
                [ code [ Util.testAttribute <| String.join "-" [ "log", "data", props.resourceType, props.resourceNumber, String.fromInt lineNumber ] ]
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
                        List.head <| Array.toList <| .lines <| Ansi.Log.update log_ defaultAnsiLogModel
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
    span (styleAttributesAnsi chunk.style) children


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


{-| lineFocusButton : renders button for focusing log line ranges
-}
lineFocusButton : Shared.Model -> Props msg -> Int -> Html msg
lineFocusButton shared props lineNumber =
    button
        [ Util.onClickPreventDefault <|
            props.msgs.focusLine <|
                Focus.lineRangeId props.resourceType props.resourceNumber lineNumber props.lineFocus shared.shift
        , Util.testAttribute <| String.join "-" [ "log", "line", "num", props.resourceType, props.resourceNumber, String.fromInt lineNumber ]
        , id <| Focus.resourceAndLineToFocusId props.resourceType props.resourceNumber lineNumber
        , class "line-number"
        , class "button"
        , class "-link"
        , attribute "aria-label" <| "focus " ++ props.resourceType ++ " " ++ props.resourceNumber
        ]
        [ span [] [ text <| String.fromInt lineNumber ] ]


{-| logsHeader : takes number, filename and decoded log and renders logs header
-}
logsHeader : Props msg -> String -> Vela.Log -> Html msg
logsHeader props fileName log =
    div
        [ class "logs-header"
        , class "buttons"

        -- , Util.testAttribute <| "logs-header-actions-" ++ props.number
        ]
        [-- downloadLogsButton props.msgs.download resourceType number fileName log
        ]


{-| logsSidebar : takes number/following and renders the logs sidebar
-}
logsSidebar : Props msg -> Int -> Html msg
logsSidebar props numLines =
    let
        long =
            numLines > 25
    in
    div [ class "logs-sidebar" ]
        [ div [ class "inner-container" ]
            [ div
                [ class "actions"

                -- , Util.testAttribute <| "logs-sidebar-actions-" ++ props.number
                ]
              <|
                (if long then
                    [--     jumpToTopButton props.msgs.focusOn props.resourceType props.number
                     -- , jumpToBottomButton props.msgs.focusOn props.resourceType props.number
                    ]

                 else
                    []
                )
                    ++ [-- followButton props.msgs.follow resourceType number following
                       ]
            ]
        ]



-- {-| jumpToBottomButton : renders action button for jumping to the bottom of a log
-- -}
-- jumpToBottomButton : FocusOn msg -> String -> String -> Html msg
-- jumpToBottomButton focusOn resourceType number =
--     button
--         [ class "button"
--         , class "-icon"
--         , class "tooltip-left"
--         , attribute "data-tooltip" "jump to bottom"
--         , Util.testAttribute <| "jump-to-bottom-" ++ number
--         , onClick <| focusOn <| bottomTrackerFocusId resourceType number
--         , attribute "aria-label" <| "jump to bottom of logs for " ++ resourceType ++ " " ++ number
--         ]
--         [ FeatherIcons.arrowDown |> FeatherIcons.toHtml [ attribute "role" "img" ] ]
-- {-| jumpToTopButton : renders action button for jumping to the top of a log
-- -}
-- jumpToTopButton : FocusOn msg -> String -> String -> Html msg
-- jumpToTopButton focusOn resourceType number =
--     button
--         [ class "button"
--         , class "-icon"
--         , class "tooltip-left"
--         , attribute "data-tooltip" "jump to top"
--         , Util.testAttribute <| "jump-to-top-" ++ number
--         , onClick <| focusOn <| topTrackerFocusId resourceType number
--         , attribute "aria-label" <| "jump to top of logs for " ++ resourceType ++ " " ++ number
--         ]
--         [ FeatherIcons.arrowUp |> FeatherIcons.toHtml [ attribute "role" "img" ] ]
-- {-| downloadLogsButton : renders action button for downloading a log
-- -}
-- downloadLogsButton : Download msg -> String -> String -> String -> Vela.Log -> Html msg
-- downloadLogsButton download resourceType number fileName log =
--     let
--         logEmpty =
--             isEmpty log
--     in
--     button
--         [ class "button"
--         , class "-link"
--         , Html.Attributes.disabled logEmpty
--         , Util.attrIf logEmpty <| class "-hidden"
--         , Util.attrIf logEmpty <| Util.ariaHidden
--         , Util.testAttribute <| "download-logs-" ++ number
--         , onClick <| download fileName log.rawData
--         , attribute "aria-label" <| "download logs for " ++ resourceType ++ " " ++ number
--         ]
--         [ text <| "download " ++ resourceType ++ " logs" ]
-- {-| followButton : renders button for following logs
-- -}
-- followButton : FollowResource msg -> String -> String -> Int -> Html msg
-- followButton followStep resourceType number following =
--     let
--         num =
--             Maybe.withDefault 0 <| String.toInt number
--         ( tooltip, icon, toFollow ) =
--             if following == 0 then
--                 ( "start following " ++ resourceType ++ " logs", FeatherIcons.play, num )
--             else if following == num then
--                 ( "stop following " ++ resourceType ++ " logs", FeatherIcons.pause, 0 )
--             else
--                 ( "start following " ++ resourceType ++ " logs", FeatherIcons.play, num )
--     in
--     button
--         [ class "button"
--         , class "-icon"
--         , class "tooltip-left"
--         , attribute "data-tooltip" tooltip
--         , Util.testAttribute <| "follow-logs-" ++ number
--         , onClick <| followStep toFollow
--         , attribute "aria-label" <| tooltip ++ " for " ++ resourceType ++ " " ++ number
--         ]
--         [ icon |> FeatherIcons.toHtml [ attribute "role" "img", attribute "aria-label" "show build actions" ] ]
-- HELPERS


{-| safeDecodeLogData : takes log and decodes the data if it exists and does not exceed the size limit.
-}
safeDecodeLogData : Int -> Vela.Log -> Maybe (WebData Vela.Log) -> Maybe (WebData Vela.Log)
safeDecodeLogData sizeLimitBytes inLog inExistingLog =
    let
        existingLog =
            inExistingLog
                |> Maybe.withDefault RemoteData.NotAsked
                |> RemoteData.unwrap { rawData = "", decodedLogs = "" }
                    (\l -> { rawData = l.rawData, decodedLogs = l.decodedLogs })

        decoded =
            if inLog.size == 0 then
                "The build has not written anything to this log yet."

            else if inLog.size > sizeLimitBytes then
                "The data for this log exceeds the size limit of "
                    ++ Util.formatFilesize sizeLimitBytes
                    ++ ".\n"
                    ++ "To view this log use the CLI or click the 'download' link in the top right corner (downloading may take a few moments, depending on the size of the file)."

            else if inLog.rawData == existingLog.rawData then
                existingLog.decodedLogs

            else
                Util.base64Decode inLog.rawData
    in
    Just <| RemoteData.succeed { inLog | decodedLogs = decoded }



-- ANSI


{-| defaultAnsiLogModel : struct to represent default model required by ANSI parser
-}
defaultAnsiLogModel : Ansi.Log.Model
defaultAnsiLogModel =
    { lineDiscipline = Ansi.Log.Cooked
    , lines = Array.empty
    , position = defaultPosition
    , savedPosition = Nothing
    , style = defaultAnsiLogStyle
    , remainder = ""
    }


{-| defaultAnsiLogStyle : struct to represent default style required by ANSI model
-}
defaultAnsiLogStyle : Ansi.Log.Style
defaultAnsiLogStyle =
    { foreground = Nothing
    , background = Nothing
    , bold = False
    , faint = False
    , italic = False
    , underline = False
    , blink = False
    , inverted = False
    , fraktur = False
    , framed = False
    }


{-| defaultPosition : default ANSI cursor position
-}
defaultPosition : Ansi.Log.CursorPosition
defaultPosition =
    { row = 0
    , column = 0
    }


{-| decodeAnsi : takes maybe log parses into ansi decoded log line array
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
-}
decodeAnsi : String -> Array.Array Ansi.Log.Line
decodeAnsi log =
    .lines <| Ansi.Log.update log defaultAnsiLogModel


{-| styleAttributesAnsi : takes Ansi.Log.Style and renders it into ANSI style Html attributes
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled in unmodified because elm-ansi does not expose it
-}
styleAttributesAnsi : Ansi.Log.Style -> List (Html.Attribute msg)
styleAttributesAnsi logStyle =
    [ style "font-weight"
        (if logStyle.bold then
            "bold"

         else
            "normal"
        )
    , style "text-decoration"
        (if logStyle.underline then
            "underline"

         else
            "none"
        )
    , style "font-style"
        (if logStyle.italic then
            "italic"

         else
            "normal"
        )
    , let
        fgClasses =
            colorClassesAnsi "-fg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.foreground

                 else
                    logStyle.background
                )

        bgClasses =
            colorClassesAnsi "-bg"
                logStyle.bold
                (if not logStyle.inverted then
                    logStyle.background

                 else
                    logStyle.foreground
                )

        fgbgClasses =
            List.map (\a -> (\b c -> ( b, c )) a True) (fgClasses ++ bgClasses)

        ansiClasses =
            [ ( "ansi-blink", logStyle.blink )
            , ( "ansi-faint", logStyle.faint )
            , ( "ansi-Fraktur", logStyle.fraktur )
            , ( "ansi-framed", logStyle.framed )
            ]
      in
      classList (fgbgClasses ++ ansiClasses)
    ]


{-| colorClassesAnsi : takes style parameters and renders it into ANSI styled color classes that can be used with the Html style attribute
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled unmodified in because elm-ansi does not expose it
-}
colorClassesAnsi : String -> Bool -> Maybe Ansi.Color -> List String
colorClassesAnsi suffix bold mc =
    let
        brightPrefix =
            "ansi-bright-"

        prefix =
            if bold then
                brightPrefix

            else
                "ansi-"
    in
    case mc of
        Nothing ->
            if bold then
                [ "ansi-bold" ]

            else
                []

        Just Ansi.Black ->
            [ prefix ++ "black" ++ suffix ]

        Just Ansi.Red ->
            [ prefix ++ "red" ++ suffix ]

        Just Ansi.Green ->
            [ prefix ++ "green" ++ suffix ]

        Just Ansi.Yellow ->
            [ prefix ++ "yellow" ++ suffix ]

        Just Ansi.Blue ->
            [ prefix ++ "blue" ++ suffix ]

        Just Ansi.Magenta ->
            [ prefix ++ "magenta" ++ suffix ]

        Just Ansi.Cyan ->
            [ prefix ++ "cyan" ++ suffix ]

        Just Ansi.White ->
            [ prefix ++ "white" ++ suffix ]

        Just Ansi.BrightBlack ->
            [ brightPrefix ++ "black" ++ suffix ]

        Just Ansi.BrightRed ->
            [ brightPrefix ++ "red" ++ suffix ]

        Just Ansi.BrightGreen ->
            [ brightPrefix ++ "green" ++ suffix ]

        Just Ansi.BrightYellow ->
            [ brightPrefix ++ "yellow" ++ suffix ]

        Just Ansi.BrightBlue ->
            [ brightPrefix ++ "blue" ++ suffix ]

        Just Ansi.BrightMagenta ->
            [ brightPrefix ++ "magenta" ++ suffix ]

        Just Ansi.BrightCyan ->
            [ brightPrefix ++ "cyan" ++ suffix ]

        Just Ansi.BrightWhite ->
            [ brightPrefix ++ "white" ++ suffix ]
