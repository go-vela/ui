{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Util exposing
    ( ariaHidden
    , dateToHumanReadable
    , dispatch
    , filterEmptyLists
    , fiveSecondsMillis
    , formatRunTime
    , formatTestTag
    , isLoading
    , isSuccess
    , largeLoader
    , millisToSeconds
    , oneSecondMillis
    , open
    , pluralize
    , relativeTimeNoSeconds
    , secondsToMillis
    , smallLoader
    , smallLoaderWithText
    , testAttribute
    , toTwoDigits
    )

import DateFormat exposing (monthNameFull)
import DateFormat.Relative exposing (defaultRelativeOptions, relativeTimeWithOptions)
import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (attribute, class)
import RemoteData exposing (WebData)
import Task exposing (perform, succeed)
import Time exposing (Posix, Zone, posixToMillis)


{-| testAttribute : returns an html attribute that produces msgs for selecting the element during automated testing
-}
testAttribute : String -> Attribute msg
testAttribute tag =
    attribute "data-test" tag


{-| secondsToMillis : converts seconds to milliseconds
-}
secondsToMillis : Int -> Int
secondsToMillis seconds =
    seconds * 1000


{-| millisToSeconds : converts milliseconds posix to seconds
-}
millisToSeconds : Int -> Int
millisToSeconds millis =
    millis // 1000


{-| dateToHumanReadable : takes timezone and posix timestamp and returns human readable date string
-}
dateToHumanReadable : Zone -> Int -> String
dateToHumanReadable timezone time =
    humanReadableDateFormatter timezone <| Time.millisToPosix <| secondsToMillis time


{-| humanReadableDateFormatter : formats a zone and time into human readable chunks
-}
humanReadableDateFormatter : Zone -> Posix -> String
humanReadableDateFormatter =
    DateFormat.format
        [ DateFormat.monthNameFull
        , DateFormat.text " "
        , DateFormat.dayOfMonthSuffix
        , DateFormat.text ", "
        , DateFormat.yearNumber
        ]


{-| relativeTimeNoSeconds : helper for using DateFormat.Relative.relativeTime with no seconds granularity
-}
relativeTimeNoSeconds : Posix -> Posix -> String
relativeTimeNoSeconds now then_ =
    relativeTimeWithOptions { defaultRelativeOptions | someSecondsAgo = noSomeSecondsAgo } now then_


{-| noSomeSecondsAgo : helper for configurating DateFormat.Relative.relativeTime
-}
noSomeSecondsAgo : Int -> String
noSomeSecondsAgo _ =
    "just now"


{-| formatRunTime : calculates build runtime using current application time and build times
-}
formatRunTime : Posix -> Int -> Int -> String
formatRunTime now started finished =
    let
        runtime =
            buildRunTime now started finished

        minutes =
            runTimeMinutes runtime

        seconds =
            runTimeSeconds runtime
    in
    String.join ":" [ minutes, seconds ]


{-| buildRunTime : calculates build runtime using current application time and build times, returned in seconds
-}
buildRunTime : Posix -> Int -> Int -> Int
buildRunTime now started finished =
    let
        start =
            started

        end =
            if finished /= 0 then
                finished

            else if started == 0 then
                start

            else
                millisToSeconds <| posixToMillis now
    in
    end - start


{-| runTimeMinutes : takes runtime in seconds, extracts minutes, and pads with necessary 0's
-}
runTimeMinutes : Int -> String
runTimeMinutes seconds =
    toTwoDigits <| seconds // 60


{-| runTimeSeconds : takes runtime in seconds, extracts seconds, and pads with necessary 0's
-}
runTimeSeconds : Int -> String
runTimeSeconds seconds =
    toTwoDigits <| Basics.remainderBy 60 seconds


{-| toTwoDigits : takes an integer of time and pads with necessary 0's

    0  seconds -> "00"
    9  seconds -> "09"
    15 seconds -> "15"

-}
toTwoDigits : Int -> String
toTwoDigits int =
    String.padLeft 2 '0' <| String.fromInt int


{-| formatTestTag : formats a test attribute tag by lower casing and replacing spaces with '-'
-}
formatTestTag : String -> String
formatTestTag tag =
    String.replace " " "-" <| String.toLower tag


{-| filterEmptyLists : filters out empties from list of (key, list)
-}
filterEmptyLists : List ( b, List a ) -> List ( b, List a )
filterEmptyLists =
    List.filter (\( _, list ) -> List.isEmpty list == False)


{-| oneSecondMillis : single second in milliseconds for clock tick subscriptions
-}
oneSecondMillis : Float
oneSecondMillis =
    1000


{-| fiveSecondsMillis : five seconds in milliseconds for clock tick subscriptions
-}
fiveSecondsMillis : Float
fiveSecondsMillis =
    oneSecondMillis * 5


{-| isLoading : takes WebData and returns true if it is in a Loading state
-}
isLoading : WebData a -> Bool
isLoading status =
    case status of
        RemoteData.Loading ->
            True

        _ ->
            False


{-| isSuccess : takes WebData and returns true if it is in a Success state
-}
isSuccess : WebData a -> Bool
isSuccess status =
    case status of
        RemoteData.Success _ ->
            True

        _ ->
            False


{-| dispatch : performs an always-succeed task to push a Cmd Msg to update in loops
-}
dispatch : msg -> Cmd msg
dispatch msg =
    succeed msg
        |> perform identity


{-| open : returns html attribute for open/closed details summaries
-}
open : Bool -> Html.Attribute msg
open isOpen =
    if isOpen then
        attribute "open" ""

    else
        class ""


{-| ariaHidden: returns the html attribute for setting aria-hidden=true
-}
ariaHidden : Html.Attribute msg
ariaHidden =
    attribute "aria-hidden" "true"


{-| smallLoader : renders a small loading spinner for better transitioning UX
-}
smallLoader : Html msg
smallLoader =
    div [ class "small-loader" ] [ div [ class "-spinner" ] [], div [ class "-label" ] [] ]


{-| smallLoaderWithText : renders a small loading spinner for better transitioning UX with additional loading text
-}
smallLoaderWithText : String -> Html msg
smallLoaderWithText label =
    div [ class "small-loader" ] [ div [ class "-spinner" ] [], div [ class "-label" ] [ text label ] ]


{-| largeLoader : renders a small loading spinner for better transitioning UX
-}
largeLoader : Html msg
largeLoader =
    div [ class "large-loader" ] [ div [ class "-spinner" ] [], div [ class "-label" ] [] ]


{-| pluralize : takes num and string and adds pluralize s if needed
-}
pluralize : Int -> String -> String
pluralize num str =
    if num > 1 then
        str ++ "s"

    else
        str
