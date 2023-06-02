{--
Copyright (c) 2022 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( addLog
    , bottomTrackerFocusId
    , clickResource
    , decodeANSI
    , defaultANSILogModel
    , downloadFileName
    , expandActive
    , focusAndClear
    , getLog
    , isEmpty
    , isViewing
    , merge
    , processLog
    , setAllViews
    , topTrackerFocusId
    , updateLog
    )

import Ansi
import Ansi.Log
import Array
import Focus exposing (FocusTarget, parseFocusFragment)
import Html exposing (Html, a, text)
import Html.Attributes exposing (href)
import List.Extra exposing (updateIf)
import Pages.Build.Model exposing (LogLine)
import RemoteData exposing (WebData)
import Url
import Util exposing (overwriteById)
import Vela
    exposing
        ( BuildNumber
        , FocusFragment
        , Log
        , LogFocus
        , Logs
        , Org
        , Repo
        , Resource
        , Resources
        )



-- HELPERS


{-| clickResource : takes resources and resource number, toggles resource view state, and returns whether or not to fetch logs
-}
clickResource : WebData (Resources a) -> String -> ( WebData (Resources a), Bool )
clickResource resources resourceID =
    resources
        |> RemoteData.unwrap ( resources, False )
            (\resources_ ->
                ( toggleView resourceID resources_ |> RemoteData.succeed
                , True
                )
            )


{-| merge : takes takes current resources and incoming resource information and merges them, updating old logs and retaining previous state.
-}
merge : Maybe String -> Bool -> WebData (Resources a) -> Resources a -> Resources a
merge logFocus refresh current incoming =
    let
        merged =
            current
                |> RemoteData.unwrap incoming
                    (\resources ->
                        incoming
                            |> List.map
                                (\r ->
                                    let
                                        ( viewing, f ) =
                                            getInfo resources r.number

                                        s =
                                            { r
                                                | viewing = viewing
                                                , logFocus = f
                                            }
                                    in
                                    Just <| Maybe.withDefault s <| overwriteById s resources
                                )
                            |> List.filterMap identity
                    )
    in
    -- when not an automatic refresh, respect the url focus
    if not refresh then
        focus logFocus merged

    else
        merged


{-| isViewing : takes resources and resource number and returns the resource viewing state
-}
isViewing : WebData (Resources a) -> String -> Bool
isViewing resources number =
    resources
        |> RemoteData.withDefault []
        |> List.filter (\resource -> String.fromInt resource.number == number)
        |> List.map .viewing
        |> List.head
        |> Maybe.withDefault False


{-| toggleView : takes resources and resource number and toggles that resource viewing state
-}
toggleView : String -> Resources a -> Resources a
toggleView number =
    List.Extra.updateIf
        (\resource -> String.fromInt resource.number == number)
        (\resource -> { resource | viewing = not resource.viewing })


{-| setAllViews : takes resources and value and sets all resources viewing state
-}
setAllViews : Bool -> Resources a -> Resources a
setAllViews value =
    List.map (\resource -> { resource | viewing = value })


{-| expandActive : takes resources and sets resource viewing state if the resource is active
-}
expandActive : String -> Resources a -> Resources a
expandActive number resources =
    List.Extra.updateIf
        (\resource -> (String.fromInt resource.number == number) && (resource.status /= Vela.Pending))
        (\resource -> { resource | viewing = True })
        resources


{-| getInfo : takes resources and resource number and returns the resource update information
-}
getInfo : Resources a -> Int -> ( Bool, LogFocus )
getInfo resources number =
    resources
        |> List.filter (\resource -> resource.number == number)
        |> List.map (\resource -> ( resource.viewing, resource.logFocus ))
        |> List.head
        |> Maybe.withDefault ( False, ( Nothing, Nothing ) )


{-| getLog : takes resource and logs and returns the log corresponding to that resource
-}
getLog : Resource a -> (Log -> Int) -> Logs -> Maybe (WebData Log)
getLog resource get logs =
    logs
        |> List.filter
            (\log ->
                case log of
                    RemoteData.Success log_ ->
                        get log_ == resource.id

                    _ ->
                        False
            )
        |> List.head


{-| addLog : takes incoming log and logs and adds log when not present
-}
addLog : Log -> Logs -> Int -> Logs
addLog incomingLog logs limit =
    RemoteData.succeed
        (safeDecodeLogData incomingLog limit)
        :: logs


{-| updateLog : takes incoming log and logs and updates the appropriate log data
-}
updateLog : Log -> Logs -> Int -> Logs
updateLog incomingLog logs limit =
    updateIf
        (\log ->
            case log of
                RemoteData.Success log_ ->
                    incomingLog.id == log_.id && incomingLog.rawData /= log_.rawData

                _ ->
                    True
        )
        (\_ ->
            RemoteData.succeed <|
                safeDecodeLogData incomingLog limit
        )
        logs


{-| safeDecodeLogData : takes log and decodes the data if it exists and does not exceed the size limit.
-}
safeDecodeLogData : Log -> Int -> Log
safeDecodeLogData log limit =
    let
        decoded =
            if isEmpty log then
                logEmptyMessage

            else if log.size > limit then
                logSizeExceededMessage limit

            else
                Util.base64Decode log.rawData
    in
    { log | decodedLogs = decoded }


{-| isEmpty : takes log and returns true if log contains no data
-}
isEmpty : Log -> Bool
isEmpty log =
    log.size == 0


{-| logEmptyMessage : returns the default message when log data does not exist.
-}
logEmptyMessage : String
logEmptyMessage =
    "The build has not written logs to this step yet."


{-| logSizeExceededMessage : returns the default message when a log exceeds the size limit.
-}
logSizeExceededMessage : Int -> String
logSizeExceededMessage limit =
    "The data for this log exceeds the size limit of "
        ++ Util.formatFilesize limit
        ++ ".\n"
        ++ "To view this log use the CLI or click the 'download' link in the top right corner of this step (downloading may take a few moments, depending on the size of the file)."


{-| focus : takes FocusFragment URL fragment and expands the appropriate resource to automatically view
-}
focus : FocusFragment -> Resources a -> Resources a
focus focusFragment resources =
    let
        ft =
            parseFocusFragment focusFragment
    in
    case Maybe.withDefault "" ft.target of
        "step" ->
            case ft.resourceID of
                Just n ->
                    set ft n resources

                Nothing ->
                    resources

        "service" ->
            case ft.resourceID of
                Just n ->
                    set ft n resources

                Nothing ->
                    resources

        _ ->
            resources


{-| focusAndClear : takes resources and line focus and sets a new log line focus
-}
focusAndClear : Resources a -> FocusFragment -> Resources a
focusAndClear resources focusFragment =
    let
        ft =
            parseFocusFragment focusFragment

        ( target, id ) =
            ( ft.target, ft.resourceID )
    in
    case Maybe.withDefault "" target of
        "step" ->
            case id of
                Just n ->
                    setAndClear ft n resources

                Nothing ->
                    resources

        "service" ->
            case id of
                Just n ->
                    setAndClear ft n resources

                Nothing ->
                    resources

        _ ->
            resources


{-| set : takes focus target and resource number, sets the log focus
-}
set : FocusTarget -> Int -> Resources a -> Resources a
set ft n =
    updateIf (\r -> r.number == n)
        (\r -> { r | viewing = True, logFocus = ( ft.lineA, ft.lineB ) })


{-| setAndClear : takes focus target and resource number, sets the log focus and clears all other resources
-}
setAndClear : FocusTarget -> Int -> Resources a -> Resources a
setAndClear ft n resources =
    resources
        |> List.map
            (\r ->
                if r.number == n then
                    { r | viewing = True, logFocus = ( ft.lineA, ft.lineB ) }

                else
                    clear r
            )


{-| clear : takes resource and clears all log line focus
-}
clear : Resource a -> Resource a
clear resource =
    { resource | logFocus = ( Nothing, Nothing ) }


{-| topTrackerFocusId : takes resource number and returns the line focus id for auto focusing on log follow
-}
topTrackerFocusId : String -> String -> String
topTrackerFocusId resource number =
    resource ++ "-" ++ number ++ "-line-tracker-top"


{-| bottomTrackerFocusId : takes resource number and returns the line focus id for auto focusing on log follow
-}
bottomTrackerFocusId : String -> String -> String
bottomTrackerFocusId resource number =
    resource ++ "-" ++ number ++ "-line-tracker-bottom"


{-| downloadFileName : takes resource information and produces a filename for downloading logs
-}
downloadFileName : Org -> Repo -> BuildNumber -> String -> String -> String
downloadFileName org repo buildNumber resourceType resourceNumber =
    String.join "-" [ org, repo, buildNumber, resourceType, resourceNumber ]


{-| processLog : takes a log as string, splits it by newline, and processes it into a model that can render custom elements like timestamps and links
-}
processLog : String -> List (LogLine msg)
processLog log =
    log
        |> String.split "\n"
        |> List.map
            (\log_ ->
                let
                    -- first we convert the log into an ANSI Log Model
                    -- this lets us preserve the original ANSI style while applying our own processing
                    ansiLogModel =
                        Ansi.Log.update log_ defaultANSILogModel

                    -- next we take the ANSI Model, run custom processing like link parsing, then render it to Html
                    logView =
                        -- we need to ignore extra empty lines generated by Ansi.Log.update
                        case List.head <| Array.toList ansiLogModel.lines of
                            Just logLine ->
                                -- we may need to extend this to accept user preferences
                                -- for example, a user may choose to not render links
                                processAndViewLine logLine

                            Nothing ->
                                text ""
                in
                -- pack the log into a model to make it more flexible when rendering later
                -- this is particularly useful for adding toggleable features like timestamps
                LogLine logView
            )


{-| parseLinksInChunk : takes Ansi.Log.Chunk and performs additional processing to parse links
-}
parseLinksInChunk : Ansi.Log.Chunk -> List (Html msg)
parseLinksInChunk chunk =
    let
        -- split the "line" by escape characters
        -- its possible this will split a "valid" link containing quote characters, but its a willing risk
        split =
            List.foldl Util.splitIntersperseConcat [ chunk.text ] linkEscapeCharacters
    in
    -- "process" each "split chunk" and check for link
    List.map
        (\chunk_ ->
            case Url.fromString chunk_ of
                Just link ->
                    -- use toString in href to make the link safe
                    a [ Util.testAttribute "log-line-link", href <| Url.toString link ] [ text chunk_ ]

                Nothing ->
                    text chunk_
        )
        split


{-| linkEscapeCharacters : list of string escape characters that delimit links.
for example "<https://github.com"> should be split from the quotes, even though " is a valid URL character (see: see: <https://www.rfc-editor.org/rfc/rfc3986#section-2>)
-}
linkEscapeCharacters : List String
linkEscapeCharacters =
    [ "'", " ", "\"", "\t", "\n" ]



-- ANSI


{-| defaultANSILogModel : struct to represent default model required by ANSI parser
-}
defaultANSILogModel : Ansi.Log.Model
defaultANSILogModel =
    { lineDiscipline = Ansi.Log.Cooked
    , lines = Array.empty
    , position = defaultPosition
    , savedPosition = Nothing
    , style = defaultANSILogStyle
    , remainder = ""
    }


{-| defaultANSILogStyle : struct to represent default style required by ANSI model
-}
defaultANSILogStyle : Ansi.Log.Style
defaultANSILogStyle =
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


{-| decodeANSI : takes maybe log parses into ansi decoded log line array
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
-}
decodeANSI : String -> Array.Array Ansi.Log.Line
decodeANSI log =
    .lines <| Ansi.Log.update log defaultANSILogModel


{-| processAndViewLine : takes Ansi.Log.Line and renders it into Html with ANSI styling
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been modified to allow custom processing
-}
processAndViewLine : Ansi.Log.Line -> Html.Html msg
processAndViewLine ( chunks, _ ) =
    Html.div [] (List.foldl (\c l -> viewChunk c :: l) [ Html.text "\n" ] chunks)


{-| viewChunk : takes Ansi.Log.Chunk and renders it into Html with ANSI styling
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been modified to allow custom processing
-}
viewChunk : Ansi.Log.Chunk -> Html.Html msg
viewChunk chunk =
    Html.span (styleAttributes chunk.style) <|
        parseLinksInChunk chunk


{-| styleAttributes : takes Ansi.Log.Style and renders it into ANSI style Html attributes
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled in unmodified because elm-ansi does not expose it
-}
styleAttributes : Ansi.Log.Style -> List (Html.Attribute x)
styleAttributes style =
    [ Html.Attributes.style "font-weight"
        (if style.bold then
            "bold"

         else
            "normal"
        )
    , Html.Attributes.style "text-decoration"
        (if style.underline then
            "underline"

         else
            "none"
        )
    , Html.Attributes.style "font-style"
        (if style.italic then
            "italic"

         else
            "normal"
        )
    , let
        fgClasses =
            colorClasses "-fg"
                style.bold
                (if not style.inverted then
                    style.foreground

                 else
                    style.background
                )

        bgClasses =
            colorClasses "-bg"
                style.bold
                (if not style.inverted then
                    style.background

                 else
                    style.foreground
                )

        fgbgClasses =
            List.map (\a -> (\b c -> ( b, c )) a True) (fgClasses ++ bgClasses)

        ansiClasses =
            [ ( "ansi-blink", style.blink )
            , ( "ansi-faint", style.faint )
            , ( "ansi-Fraktur", style.fraktur )
            , ( "ansi-framed", style.framed )
            ]
      in
      Html.Attributes.classList (fgbgClasses ++ ansiClasses)
    ]


{-| colorClasses : takes style parameters and renders it into ANSI styled color classes that can be used with the Html style attribute
see: <https://package.elm-lang.org/packages/vito/elm-ansi>
this function has been pulled unmodified in because elm-ansi does not expose it
-}
colorClasses : String -> Bool -> Maybe Ansi.Color -> List String
colorClasses suffix bold mc =
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
