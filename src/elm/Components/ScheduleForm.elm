{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.ScheduleForm exposing (viewCronHelp, viewEnabledInput, viewHelp, viewSchedulesNotAllowedWarning, viewSubmitButton)

import Components.Form
import Html
    exposing
        ( Html
        , a
        , button
        , div
        , em
        , section
        , span
        , strong
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , href
        , target
        , value
        )
import Html.Events exposing (onClick)
import Time
import Utils.Helpers as Util



-- VIEW


viewCronHelp : Time.Posix -> Html msg
viewCronHelp time =
    span []
        [ a
            [ class "field-help-link"
            , href "https://crontab.guru/"
            ]
            [ text "help" ]
        , span [ class "field-description" ]
            [ text "( "
            , em [] [ text <| "Expressions are evaluated in UTC, time now is " ]
            , text <| Util.toUtcString time
            , text " )"
            ]
        ]


viewEnabledInput : { msg : String -> msg, value : Bool, disabled_ : Bool } -> Html msg
viewEnabledInput { msg, value, disabled_ } =
    section [ Util.testAttribute "schedule-enabled" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "Active"
                , span [ class "field-description" ]
                    [ text "( "
                    , em [] [ text "Disabled schedules will not be run" ]
                    , text " )"
                    ]
                ]
            ]
        , div
            [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "yes"
                , title = "Enabled"
                , subtitle = Nothing
                , msg = msg "yes"
                , disabled_ = disabled_
                , id_ = "schedule-active-yes"
                }
            , Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "no"
                , title = "Disabled"
                , subtitle = Nothing
                , msg = msg "no"
                , disabled_ = disabled_
                , id_ = "schedule-active-no"
                }
            ]
        ]


viewHelp : String -> Html msg
viewHelp docsUrl =
    div [ class "help" ]
        [ text "Need help? Visit our "
        , a
            [ href <| docsUrl ++ "/usage/schedule_build/"
            ]
            [ text "docs" ]
        , text "!"
        ]


viewSubmitButton : { msg : msg, disabled_ : Bool } -> Html msg
viewSubmitButton { msg, disabled_ } =
    div [ class "form-action" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick msg
            , disabled disabled_
            ]
            [ text "Submit" ]
        ]


viewSchedulesNotAllowedWarning : Html msg
viewSchedulesNotAllowedWarning =
    span [ class "not-allowed", Util.testAttribute "repo-schedule-not-allowed" ]
        [ text "Sorry, Administrators have not enabled Schedules for this repository."
        ]
