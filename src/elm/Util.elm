{--
Copyright (c) 2019 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Util exposing
    ( dateToHumanReadable
    , dispatch
    , filterEmptyLists
    , fiveSecondsMillis
    , formatTestTag
    , isLoading
    , isSuccess
    , millisToSeconds
    , oneSecondMillis
    , secondsToMillis
    , testAttribute
    )

import DateFormat exposing (monthNameFull)
import Html exposing (Attribute)
import Html.Attributes exposing (attribute)
import RemoteData exposing (WebData)
import Task exposing (perform, succeed)
import Time exposing (Posix, Zone)


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
