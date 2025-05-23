{--
SPDX-License-Identifier: Apache-2.0
--}


module Utils.Helpers exposing
    ( anyBlank
    , ariaHidden
    , attrIf
    , attrNone
    , base64Decode
    , boolToString
    , boolToYesNo
    , buildPRCommitURL
    , buildRefURL
    , checkScheduleAllowlist
    , dispatch
    , extractFocusIdFromRange
    , filterEmptyList
    , filterEmptyLists
    , fiveSecondsMillis
    , formatFilesize
    , formatRunTime
    , formatTestTag
    , formatTimeFromFloat
    , getNameFromRef
    , humanReadableDateTimeFormatter
    , humanReadableDateTimeWithDefault
    , humanReadableDateWithDefault
    , isLoaded
    , isSuccess
    , mergeListsById
    , noBlanks
    , onClickPreventDefault
    , onMouseDownSubscription
    , oneDayMillis
    , oneDaySeconds
    , oneSecondMillis
    , open
    , orgRepoFromBuildLink
    , overwriteById
    , pageToString
    , relativeTimeNoSeconds
    , secondsToMillis
    , splitFirst
    , stringToAllowlist
    , stringToMaybe
    , successful
    , testAttribute
    , toUtcString
    , trimCommitHash
    , yesNoToBool
    )

import Base64
import Browser.Events
import Bytes
import Bytes.Decode
import DateFormat
import DateFormat.Relative exposing (defaultRelativeOptions, relativeTimeWithOptions)
import Filesize
import Html exposing (Attribute)
import Html.Attributes exposing (attribute, class, classList)
import Html.Events exposing (custom)
import Json.Decode
import List.Extra
import Maybe.Extra
import RemoteData exposing (WebData)
import Route.Path
import String.Extra
import Task exposing (perform, succeed)
import Time exposing (Posix, Zone, posixToMillis, toHour, toMinute, utc)
import Url


{-| onMouseDownShowHelp : takes model and returns subscriptions for handling onMouseDown events at the browser level.
-}
onMouseDownSubscription : String -> Bool -> (Maybe Bool -> msg) -> Sub msg
onMouseDownSubscription targetId show triggerMsg =
    if show then
        Browser.Events.onMouseDown (outsideTarget targetId <| triggerMsg <| Just False)

    else
        Sub.none


{-| outsideTarget : returns decoder for handling clicks that occur from outside the currently focused/open dropdown.
-}
outsideTarget : String -> msg -> Json.Decode.Decoder msg
outsideTarget targetId msg =
    Json.Decode.field "target" (isOutsideTarget targetId)
        |> Json.Decode.andThen
            (\isOutside ->
                if isOutside then
                    Json.Decode.succeed msg

                else
                    Json.Decode.fail "inside dropdown"
            )


{-| isOutsideTarget : returns decoder for determining if click target occurred from within a specified element.
-}
isOutsideTarget : String -> Json.Decode.Decoder Bool
isOutsideTarget targetId =
    Json.Decode.oneOf
        [ Json.Decode.field "id" Json.Decode.string
            |> Json.Decode.andThen
                (\id ->
                    if targetId == id then
                        -- found match by id
                        Json.Decode.succeed False

                    else
                        -- try next decoder
                        Json.Decode.fail "continue"
                )
        , Json.Decode.lazy (\_ -> isOutsideTarget targetId |> Json.Decode.field "parentNode")

        -- fallback if all previous decoders failed
        , Json.Decode.succeed True
        ]


{-| testAttribute : returns an html attribute that produces msgs for selecting the element during automated testing.
-}
testAttribute : String -> Attribute msg
testAttribute tag =
    attribute "data-test" tag


{-| splitFirst : splits a string at the first occurrence of delimiter and returns a list of strings.
-}
splitFirst : String -> String -> List String
splitFirst delimiter str =
    case String.indexes delimiter str of
        [] ->
            [ str ]

        index :: _ ->
            let
                before =
                    String.left index str

                after =
                    String.dropLeft (index + String.length delimiter) str
            in
            [ before, after ]


{-| secondsToMillis : converts seconds to milliseconds.
-}
secondsToMillis : Int -> Int
secondsToMillis seconds =
    seconds * 1000


{-| millisToSeconds : converts milliseconds posix to seconds.
-}
millisToSeconds : Int -> Int
millisToSeconds millis =
    millis // 1000


{-| humanReadableDateWithDefault : takes timezone and posix timestamp and returns human readable date string with a default value for 0.
-}
humanReadableDateWithDefault : Zone -> Int -> String
humanReadableDateWithDefault timezone t =
    if t == 0 then
        "-"

    else
        humanReadableDateFormatter timezone <| Time.millisToPosix <| secondsToMillis t


{-| humanReadableDateTimeWithDefault : takes timezone and posix timestamp and returns human readable date time string with a default value for 0.
-}
humanReadableDateTimeWithDefault : Zone -> Int -> String
humanReadableDateTimeWithDefault timezone t =
    if t == 0 then
        "-"

    else
        humanReadableDateTimeFormatter timezone <| Time.millisToPosix <| secondsToMillis t


{-| humanReadableDateFormatter : formats a zone and date into human readable chunks.
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


{-| humanReadableDateTimeFormatter : formats a zone and date/time into human readable chunks.
-}
humanReadableDateTimeFormatter : Zone -> Posix -> String
humanReadableDateTimeFormatter =
    DateFormat.format
        [ DateFormat.monthFixed
        , DateFormat.text "/"
        , DateFormat.dayOfMonthFixed
        , DateFormat.text "/"
        , DateFormat.yearNumber
        , DateFormat.text " at "
        , DateFormat.hourFixed
        , DateFormat.text ":"
        , DateFormat.minuteFixed
        , DateFormat.text " "
        , DateFormat.amPmUppercase
        ]


{-| relativeTimeNoSeconds : helper for using DateFormat.Relative.relativeTime with no seconds granularity.
-}
relativeTimeNoSeconds : Posix -> Posix -> String
relativeTimeNoSeconds now then_ =
    relativeTimeWithOptions { defaultRelativeOptions | someSecondsAgo = noSomeSecondsAgo } now then_


{-| toUtcString : helper for using Time to convert Posix to a UTC string in the format HH:MM.
-}
toUtcString : Time.Posix -> String
toUtcString time =
    toTwoDigits (toHour utc time)
        ++ ":"
        ++ toTwoDigits (toMinute utc time)


{-| noSomeSecondsAgo : helper for configurating DateFormat.Relative.relativeTime.
-}
noSomeSecondsAgo : Int -> String
noSomeSecondsAgo _ =
    "just now"


{-| formatTimeFromFloat : takes a float (seconds) and passes it to formatTime
for a string representation. the value is floored since we don't measure
at sub-second accuraacy.
-}
formatTimeFromFloat : Float -> String
formatTimeFromFloat number =
    number
        |> floor
        |> formatTime


{-| formatTime : takes an int (seconds) and converts it to a string representation.

example: 4000 -> 1h 6m 40s

-}
formatTime : Int -> String
formatTime totalSeconds =
    let
        hours =
            totalSeconds // 3600

        remainingSeconds =
            Basics.remainderBy 3600 totalSeconds

        minutes =
            remainingSeconds // 60

        seconds =
            Basics.remainderBy 60 remainingSeconds

        hoursString =
            if hours > 0 then
                String.fromInt hours ++ "h "

            else
                ""

        minutesString =
            if minutes > 0 then
                String.fromInt minutes ++ "m "

            else
                ""
    in
    if totalSeconds < 1 then
        "0s"

    else
        hoursString ++ minutesString ++ String.fromInt seconds ++ "s"


{-| formatRunTime : calculates build runtime using current application time and build times.
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
    -- treating 00:00 as an unreasonable runtime state
    if minutes == "00" && seconds == "00" then
        "--:--"

    else
        String.join ":" [ minutes, seconds ]


{-| buildRunTime : calculates build runtime using current application time and build times, returned in seconds.
-}
buildRunTime : Posix -> Int -> Int -> Int
buildRunTime now started finished =
    let
        isValid : Int -> Bool
        isValid value =
            value > 0

        ( start, end ) =
            case ( isValid started, isValid finished ) of
                -- neither started nor finished
                ( False, False ) ->
                    ( 0, 0 )

                -- if finished but not started, we won't know duration
                ( False, True ) ->
                    ( 0, 0 )

                -- started, but not finished
                ( True, False ) ->
                    ( started, millisToSeconds <| posixToMillis now )

                -- both started and finished are legit
                -- if it finished before it started, something is very wrong
                -- otherwise, return started and finished
                ( True, True ) ->
                    if started > finished then
                        ( 0, 0 )

                    else
                        ( started, finished )
    in
    end - start


{-| runTimeMinutes : takes runtime in seconds, extracts minutes, and pads with necessary 0's.
-}
runTimeMinutes : Int -> String
runTimeMinutes seconds =
    toTwoDigits <| seconds // 60


{-| runTimeSeconds : takes runtime in seconds, extracts seconds, and pads with necessary 0's.
-}
runTimeSeconds : Int -> String
runTimeSeconds seconds =
    toTwoDigits <| Basics.remainderBy 60 seconds


{-| toTwoDigits : takes an integer of time and pads with necessary 0's.

    0  seconds -> "00"
    9  seconds -> "09"
    15 seconds -> "15"

-}
toTwoDigits : Int -> String
toTwoDigits int =
    String.padLeft 2 '0' <| String.fromInt int


{-| formatTestTag : formats a test attribute tag by lower casing and replacing spaces with '-'.
-}
formatTestTag : String -> String
formatTestTag tag =
    String.replace " " "-" <| String.toLower tag


{-| filterEmptyList : filters out empties from list of string.
-}
filterEmptyList : List String -> List String
filterEmptyList =
    List.filter (\x -> not <| String.isEmpty x)


{-| filterEmptyLists : filters out empties from list of (key, list).
-}
filterEmptyLists : List ( b, List a ) -> List ( b, List a )
filterEmptyLists =
    List.filter (\( _, list ) -> List.isEmpty list == False)


{-| anyBlank : takes list of strings, returns true if any are blank.
-}
anyBlank : List String -> Bool
anyBlank strings =
    case List.head <| List.filter String.Extra.isBlank strings of
        Nothing ->
            False

        _ ->
            True


{-| noBlanks : takes list of strings, returns true if any are blank.
-}
noBlanks : List String -> Bool
noBlanks strings =
    not <| anyBlank strings


{-| overwriteById : takes single item and list and updates the specific item by ID, returns Nothing if no update was needed.
-}
overwriteById : { a | id : comparable } -> List { a | id : comparable } -> Maybe { a | id : comparable }
overwriteById item list =
    List.head <| List.filter (\a -> a.id == item.id) <| List.Extra.setIf (\a -> a.id == item.id) item list


{-| existsById : takes single item and list and updates the specific item by ID, returns a True if record exists, otherwise False.
-}
existsById : { a | id : comparable } -> List { a | id : comparable } -> Bool
existsById item list =
    List.length (List.filter (\a -> a.id == item.id) list) > 0


{-| mergeListsById : takes two lists and merges them by unique id.
-}
mergeListsById : List { a | id : comparable } -> List { a | id : comparable } -> List { a | id : comparable }
mergeListsById listA listB =
    List.filter (\a -> not <| existsById a listB) listA ++ listB


{-| oneSecondMillis : single second in milliseconds for clock tick subscriptions.
-}
oneSecondMillis : Float
oneSecondMillis =
    1000


{-| fiveSecondsMillis : five seconds in milliseconds for clock tick subscriptions.
-}
fiveSecondsMillis : Float
fiveSecondsMillis =
    oneSecondMillis * 5


{-| oneDaySeconds : 86400 seconds in a day
-}
oneDaySeconds : Int
oneDaySeconds =
    86400


{-| oneDayMillis : oneDaySeconds in milliseconds
-}
oneDayMillis : Int
oneDayMillis =
    secondsToMillis oneDaySeconds


{-| isLoaded : takes WebData and returns true if it is in a 'loaded' state, meaning its anything but NotAsked or Loading.
-}
isLoaded : WebData a -> Bool
isLoaded status =
    case status of
        RemoteData.Loading ->
            False

        RemoteData.NotAsked ->
            False

        _ ->
            True


{-| isSuccess : takes WebData and returns true if it is in a Success state.
-}
isSuccess : WebData a -> Bool
isSuccess status =
    case status of
        RemoteData.Success _ ->
            True

        _ ->
            False


{-| dispatch : performs an always-succeed task to push a Cmd Msg to update in loops.
-}
dispatch : msg -> Cmd msg
dispatch msg =
    succeed msg
        |> perform identity


{-| open : returns html attribute for open/closed details summaries.
-}
open : Bool -> List (Html.Attribute msg)
open isOpen =
    if isOpen then
        [ attribute "open" "" ]

    else
        []


{-| ariaHidden : returns the html attribute for setting aria-hidden=true.
-}
ariaHidden : Html.Attribute msg
ariaHidden =
    attribute "aria-hidden" "true"


{-| attrIf : takes a Bool and returns either the Html.Attribute or the Html equivalent of nothing.
-}
attrIf : Bool -> Html.Attribute msg -> Html.Attribute msg
attrIf cond attr =
    if cond then
        attr

    else
        class ""


{-| attrNone : returns the Html.Attribute equivalent of nothing.
-}
attrNone : Html.Attribute msg
attrNone =
    classList []


{-| boolToString : takes bool and converts to true/false string.
-}
boolToString : Bool -> String
boolToString bool =
    if bool then
        "true"

    else
        "false"


{-| boolToYesNo : takes bool and converts to yes/no string.
-}
boolToYesNo : Bool -> String
boolToYesNo bool =
    if bool then
        "yes"

    else
        "no"


{-| yesNoToBool : takes yes/no string and converts to bool.
-}
yesNoToBool : String -> Bool
yesNoToBool yesNo =
    yesNo == "yes"


{-| stringToMaybe : takes string and returns nothing if trimmed string is empty.
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


{-| onClickPreventDefault : returns custom onClick handler for calling javascript function preventDefault().
-}
onClickPreventDefault : msg -> Html.Attribute msg
onClickPreventDefault message =
    custom "click" (Json.Decode.succeed { message = message, stopPropagation = False, preventDefault = True })


{-| successful : extracts successful items from list of WebData items and returns List item.
-}
successful : List (WebData a) -> List a
successful =
    List.filterMap
        (\item ->
            case item of
                RemoteData.Success item_ ->
                    Just item_

                _ ->
                    Nothing
        )


{-| extractFocusIdFromRange : takes focusId with possible range and extracts the id to focus on.
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


{-| base64Decode : takes string and decodes it from base64.
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


{-| pageToString : small helper to turn page number to a string to display in crumbs.
-}
pageToString : Maybe String -> String
pageToString maybePage =
    maybePage
        |> Maybe.map String.toInt
        |> Maybe.withDefault Nothing
        |> Maybe.Extra.unwrap ""
            (\num ->
                if num > 1 then
                    " (page " ++ String.fromInt num ++ ")"

                else
                    ""
            )


{-| buildRefURL : drops '.git' off the clone url and concatenates tree + ref.
-}
buildRefURL : String -> String -> String
buildRefURL clone ref =
    String.dropRight 4 clone ++ "/tree/" ++ ref


{-| orgRepoFromBuildLink : takes build and uses the link field to parse out org and repo
if the build link has a host, then URL is used to parse, otherwise it splits on '/'.
-}
orgRepoFromBuildLink : String -> ( String, String )
orgRepoFromBuildLink link =
    let
        path =
            link
                |> Url.fromString
                |> Maybe.Extra.unwrap link .path
    in
    case Route.Path.fromString path of
        Just (Route.Path.Org__Repo__Build_ params) ->
            ( params.org, params.repo )

        _ ->
            ( Maybe.withDefault "" <| List.head (List.drop 1 (String.split "/" path))
            , Maybe.withDefault "" <| List.head (List.drop 2 (String.split "/" path))
            )


{-| buildPRCommitURL : creates a direct link to a commit in a PR.
-}
buildPRCommitURL : String -> String -> String
buildPRCommitURL source commit =
    source ++ "/commits/" ++ commit


{-| trimCommitHash : takes the first 7 characters of the full commit hash.
-}
trimCommitHash : String -> String
trimCommitHash commit =
    String.left 7 commit


{-| getNameFromRef : parses the name from git for easy consumption.
-}
getNameFromRef : String -> String
getNameFromRef s =
    let
        sp =
            String.split "/" s

        n =
            List.head (List.drop 2 sp)
    in
    case n of
        Just name ->
            name

        _ ->
            ""


{-| formatFilesize : returns a file size in bytes as a human readable string.
Defined as a helper function to make it easier to configure bases, units etc.
see: <https://package.elm-lang.org/packages/basti1302/elm-human-readable-filesize/latest/Filesize>
-}
formatFilesize : Int -> String
formatFilesize =
    Filesize.format


{-| stringToAllowlist : takes a comma-separated string list of org/repo pairs and parses it into a list of tuples.
-}
stringToAllowlist : String -> List ( String, String )
stringToAllowlist src =
    src
        |> String.split ","
        -- split comma separated list
        |> List.map
            (\orgRepo ->
                case String.split "/" <| String.trim orgRepo of
                    -- split org/repo
                    -- deny empty values by default
                    "" :: "" :: _ ->
                        ( "", "" )

                    -- permit valid org/repo
                    org :: repo :: _ ->
                        ( org, repo )

                    -- deny empty orgs by default
                    "" :: _ ->
                        ( "", "" )

                    -- allow org wildcards when only an org is provided
                    org :: _ ->
                        ( org, "*" )

                    -- deny unparsed values by default
                    _ ->
                        ( "", "" )
            )


{-| checkScheduleAllowlist : takes org, repo and allowlist and checks if the repo exists in the list, accounting for wildcards (\*).
-}
checkScheduleAllowlist : String -> String -> List ( String, String ) -> Bool
checkScheduleAllowlist org repo allowlist =
    List.any (checkMatch ( org, repo )) allowlist


{-| checkMatch : takes two pairs of org and repo and checks if the inPair matches the allowlist srcPair.
-}
checkMatch : ( String, String ) -> ( String, String ) -> Bool
checkMatch ( inOrg, inRepo ) ( srcOrg, srcRepo ) =
    (srcOrg == "*" && srcRepo == "*")
        || (srcOrg == inOrg && srcRepo == "*")
        || (srcOrg == inOrg && srcRepo == inRepo)
