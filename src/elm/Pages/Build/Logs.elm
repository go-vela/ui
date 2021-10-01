{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( addLog
    , bottomTrackerFocusId
    , clickResource
    , decodeAnsi
    , downloadFileName
    , expandActive
    , focusAndClear
    , getLog
    , isViewing
    , merge
    , setAllViews
    , toString
    , topTrackerFocusId
    , updateLog
    )

import Ansi.Log
import Array
import Focus exposing (FocusTarget, parseFocusFragment)
import List.Extra exposing (updateIf)
import RemoteData exposing (WebData)
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


{-| logSizeLimit : returns the maximum size for log data, in bytes.
-}
logSizeLimit : Int
logSizeLimit =
    Util.megabyte * 5


{-| logEmptyMessage : returns the default message when log data does not exist.
-}
logEmptyMessage : String
logEmptyMessage =
    "No logs written to this step yet."


{-| logSizeExceededMessage : returns the default message when a log exceeds the size limit.
-}
logSizeExceededMessage : String
logSizeExceededMessage =
    "The data for this log exceeds the size limit ("
        ++ Util.formatFilesize logSizeLimit
        ++ ").\n"
        ++ "To view this log use the CLI or click the 'download' link in the top right corner of this step."


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
addLog : Log -> Logs -> Logs
addLog incomingLog logs =
    RemoteData.succeed
        (safeDecodeLogData incomingLog)
        :: logs


{-| updateLog : takes incoming log and logs and updates the appropriate log data
-}
updateLog : Log -> Logs -> Logs
updateLog incomingLog logs =
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
                safeDecodeLogData incomingLog
        )
        logs


{-| safeDecodeLogData : takes log and decodes the data if it exists and does not exceed the size limit.
-}
safeDecodeLogData : Log -> Log
safeDecodeLogData log =
    { log
        | decodedLogs =
            if isEmpty log then
                logEmptyMessage

            else if exceedsSizeLimit log then
                logSizeExceededMessage

            else
                Util.base64Decode log.rawData
    }


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


{-| toString : returns a string from a Maybe Log
-}
toString : Maybe (WebData Log) -> String
toString log =
    case log of
        Just log_ ->
            case log_ of
                RemoteData.Success l ->
                    l.decodedLogs

                _ ->
                    ""

        Nothing ->
            ""


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


{-| exceedsSizeLimit : takes log and returns true if log.data exceeds the render size limit
-}
exceedsSizeLimit : Log -> Bool
exceedsSizeLimit log =
    log.size > logSizeLimit


{-| isEmpty : takes log and returns true if log contains no data
-}
isEmpty : Log -> Bool
isEmpty log =
    log.size == 0



-- ANSI


{-| defaultLogModel : struct to represent default model required by ANSI parser
-}
defaultLogModel : Ansi.Log.Model
defaultLogModel =
    { lineDiscipline = Ansi.Log.Cooked
    , lines = Array.empty
    , position = defaultPosition
    , savedPosition = Nothing
    , style = defaultLogStyle
    , remainder = ""
    }


{-| defaultLogStyle : struct to represent default style required by ANSI model
-}
defaultLogStyle : Ansi.Log.Style
defaultLogStyle =
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
    .lines <| Ansi.Log.update log defaultLogModel
