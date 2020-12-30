{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Build.Logs exposing
    ( bottomTrackerFocusId
    , decodeAnsi
    , downloadFileName
    , focus
    , focusAndClear
    , getCurrentResource
    , getLog
    , logEmpty
    , toString
    , topTrackerFocusId
    )

import Ansi.Log
import Array
import Focus exposing (FocusTarget, parseFocusFragment, resourceFocusFragment)
import List.Extra exposing (updateIf)
import Pages exposing (Page)
import RemoteData exposing (WebData)
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


{-| getCurrentResource : takes resources and returns the newest running or pending resource
-}
getCurrentResource : Resources a -> Int
getCurrentResource resources =
    let
        resource =
            resources
                |> List.filter (\s -> s.status == Vela.Pending || s.status == Vela.Running)
                |> List.map .number
                |> List.sort
                |> List.head
                |> Maybe.withDefault 0
    in
    resource


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


{-| logEmpty : takes log string and returns True if content does not exist
-}
logEmpty : String -> Bool
logEmpty log =
    String.isEmpty <| String.replace " " "" log


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
