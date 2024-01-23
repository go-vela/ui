module Utils.Ansi exposing (..)

import Ansi
import Ansi.Log
import Array
import Html
import Html.Attributes exposing (classList, style)



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
