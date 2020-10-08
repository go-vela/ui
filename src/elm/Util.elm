{--
Copyright (c) 2020 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Util exposing
    ( addIfUniqueId
    , anyBlank
    , ariaHidden
    , base64Decode
    , boolToYesNo
    , dateToHumanReadable
    , dispatch
    , extractFocusIdFromRange
    , filterEmptyList
    , filterEmptyLists
    , filterEmptyStringLists
    , fiveSecondsMillis
    , formatRunTime
    , formatTestTag
    , getById
    , isLoading
    , isSuccess
    , largeLoader
    , mergeListsById
    , millisToSeconds
    , noBlanks
    , onClickPreventDefault
    , onClickStopPropogation
    , oneSecondMillis
    , open
    , overwriteById
    , pluralize
    , relativeTimeNoSeconds
    , secondsToMillis
    , smallLoader
    , smallLoaderWithText
    , stringToMaybe
    , successful
    , testAttribute
    , toTwoDigits
    , yesNoToBool
    )

import Base64
import Bytes
import Bytes.Decode
import DateFormat exposing (monthNameFull)
import DateFormat.Relative exposing (defaultRelativeOptions, relativeTimeWithOptions)
import Html exposing (Attribute, Html, div, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (custom)
import Json.Decode as Decode
import List.Extra
import RemoteData exposing (RemoteData(..), WebData)
import String.Extra
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


{-| filterEmptyList : filters out empties from list of string
-}
filterEmptyList : List String -> List String
filterEmptyList =
    List.filter (\x -> not <| String.isEmpty x)


{-| filterEmptyLists : filters out empties from list of (key, list)
-}
filterEmptyLists : List ( b, List a ) -> List ( b, List a )
filterEmptyLists =
    List.filter (\( _, list ) -> List.isEmpty list == False)


{-| filterEmptyStringLists : filters out empties from list of (key, list)
-}
filterEmptyStringLists : List ( String, List String ) -> List ( String, List String )
filterEmptyStringLists =
    List.filter (\( _, list ) -> List.isEmpty list == False)


{-| anyBlank : takes list of strings, returns true if any are blank
-}
anyBlank : List String -> Bool
anyBlank strings =
    case List.head <| List.filter String.Extra.isBlank strings of
        Nothing ->
            False

        _ ->
            True


{-| noBlanks : takes list of strings, returns true if any are blank
-}
noBlanks : List String -> Bool
noBlanks strings =
    not <| anyBlank strings


addIfUniqueId : { a | id : comparable } -> List { a | id : comparable } -> List { a | id : comparable }
addIfUniqueId item list =
    filterByUniqueId <| item :: list


filterByUniqueId : List { a | id : comparable } -> List { a | id : comparable }
filterByUniqueId list =
    List.Extra.uniqueBy .id list


{-| overwriteById : takes single item and list and updates the specific item by ID

    returns Nothing if no update was needed

-}
overwriteById : { a | id : comparable } -> List { a | id : comparable } -> Maybe { a | id : comparable }
overwriteById item list =
    List.head <| List.filter (\a -> a.id == item.id) <| List.Extra.setIf (\a -> a.id == item.id) item list


existsById : { a | id : comparable } -> List { a | id : comparable } -> Bool
existsById item list =
    List.length (List.filter (\a -> a.id == item.id) list) > 0


{-| getById : takes item with id and list and extracts item
-}
getById : comparable -> List { a | id : comparable } -> Maybe { a | id : comparable }
getById item list =
    List.head <| List.filter (\a -> a.id == item) list


{-| mergeListsById : takes two lists and merges them by unique id
-}
mergeListsById : List { a | id : comparable } -> List { a | id : comparable } -> List { a | id : comparable }
mergeListsById listA listB =
    List.filter (\a -> not <| existsById a listB) listA ++ listB


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
open : Bool -> List (Html.Attribute msg)
open isOpen =
    if isOpen then
        [ attribute "open" "" ]

    else
        []


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


{-| boolToYesNo : takes bool and converts to yes/no string
-}
boolToYesNo : Bool -> String
boolToYesNo bool =
    if bool then
        "yes"

    else
        "no"


{-| yesNoToBool : takes yes/no string and converts to bool
-}
yesNoToBool : String -> Bool
yesNoToBool yesNo =
    yesNo == "yes"


{-| stringToMaybe : takes string and returns nothing if trimmed string is empty
-}
stringToMaybe : String -> Maybe String
stringToMaybe str =
    let
        trimmed =
            String.trim str
    in
    if String.isEmpty trimmed then
        Nothing

    else
        Just trimmed


{-| onClickPreventDefault : returns custom onClick handler for calling javascript function preventDefault()
-}
onClickPreventDefault : msg -> Html.Attribute msg
onClickPreventDefault message =
    custom "click" (Decode.succeed { message = message, stopPropagation = False, preventDefault = True })


{-| onClickStopPropogation : returns custom onClick handler for calling javascript function stopPropogation()
-}
onClickStopPropogation : msg -> Html.Attribute msg
onClickStopPropogation message =
    custom "click" (Decode.succeed { message = message, stopPropagation = True, preventDefault = False })


{-| successful : extracts successful items from list of WebData items and returns List item
-}
successful : List (WebData a) -> List a
successful =
    List.filterMap
        (\item ->
            case item of
                Success item_ ->
                    Just item_

                _ ->
                    Nothing
        )


{-| extractFocusIdFromRange : takes focusId with possible range and extracts the id to focus on
-}
extractFocusIdFromRange : String -> String
extractFocusIdFromRange focusId =
    let
        focusArgs =
            String.split "-" focusId

        isRange =
            List.length focusArgs == 5
    in
    if isRange then
        let
            dropTail =
                List.Extra.init focusArgs
        in
        case dropTail of
            Just l ->
                String.join "-" l

            Nothing ->
                focusId

    else
        focusId


{-| base64Decode : takes string and decodes it from base64
-}
base64Decode : String -> String
base64Decode inStr =
    Base64.toBytes inStr
        |> Maybe.andThen
            (\bytes ->
                Bytes.Decode.decode
                    (Bytes.Decode.string (Bytes.width bytes))
                    bytes
            )
        |> Maybe.withDefault ""
