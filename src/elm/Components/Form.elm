{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Form exposing (viewAllowEvents, viewButton, viewCheckbox, viewInput, viewRadio, viewSubtitle, viewTextarea)

import Html exposing (Html, button, div, input, label, section, span, strong, text, textarea)
import Html.Attributes exposing (checked, class, classList, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Maybe.Extra
import Shared
import Utils.Helpers as Util
import Vela



-- VIEW


viewInput :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewInput { id_, title, subtitle, val, placeholder_, classList_, rows_, wrap_, msg, disabled_ } =
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for <| id_ ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , input
            [ id id_
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        ]


viewTextarea :
    { id_ : String
    , title : Maybe String
    , subtitle : Maybe (Html msg)
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewTextarea { id_, title, subtitle, val, placeholder_, classList_, rows_, wrap_, msg, disabled_ } =
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for <| id_ ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , textarea
            [ id id_
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        ]


viewCheckbox :
    { id_ : String
    , title : String
    , subtitle : Maybe (Html msg)
    , field : String
    , state : Bool
    , msg : Bool -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewCheckbox { id_, title, subtitle, field, state, msg, disabled_ } =
    div
        [ class "form-control"
        , Util.testAttribute <| "checkbox-" ++ field
        ]
        [ input
            [ type_ "checkbox"
            , id <| "checkbox-" ++ field
            , checked state
            , onCheck msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        , label [ class "form-label", for <| "checkbox-" ++ field ]
            [ text title, viewSubtitle subtitle ]
        ]


viewRadio :
    { id_ : String
    , title : String
    , subtitle : Maybe (Html msg)
    , value : String
    , field : String
    , msg : msg
    , disabled_ : Bool
    }
    -> Html msg
viewRadio { id_, title, subtitle, value, field, msg, disabled_ } =
    div [ class "form-control", Util.testAttribute <| "radio-" ++ field ]
        [ input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        , label [ class "form-label", for <| "radio-" ++ field ]
            [ strong [] [ text title ], viewSubtitle subtitle ]
        ]


viewButton : { id_ : String, msg : msg, text_ : String, classList_ : List ( String, Bool ), disabled_ : Bool } -> Html msg
viewButton { id_, msg, text_, classList_, disabled_ } =
    button
        [ class "button"
        , onClick msg
        , disabled disabled_
        , classList classList_
        , Util.testAttribute id_
        ]
        [ text text_ ]


viewSubtitle : Maybe (Html msg) -> Html msg
viewSubtitle subtitle =
    Maybe.Extra.unwrap (text "") (\s -> span [] [ text <| " ", s ]) subtitle


viewAllowEvents :
    Shared.Model
    ->
        { msg : { allowEvents : Vela.AllowEvents, event : String } -> Bool -> msg
        , allowEvents : Vela.AllowEvents
        , disabled_ : Bool
        }
    -> List (Html msg)
viewAllowEvents shared { msg, allowEvents } =
    [ strong [ class "settings-subtitle" ] [ text "Push" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Push"
            , subtitle = Nothing
            , field = "allow_push_branch"
            , state = allowEvents.push.branch
            , msg = msg { allowEvents = allowEvents, event = "allow_push_branch" }
            , disabled_ = False
            , id_ = "allow-events-push-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_tag"
            , state = allowEvents.push.tag
            , msg = msg { allowEvents = allowEvents, event = "allow_push_tag" }
            , disabled_ = False
            , id_ = "allow-events-push-tag"
            }
        ]
    , strong [ class "settings-subtitle" ] [ text "Pull Request" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Opened"
            , subtitle = Nothing
            , field = "allow_pull_opened"
            , state = allowEvents.pull.opened
            , msg = msg { allowEvents = allowEvents, event = "allow_pull_opened" }
            , disabled_ = False
            , id_ = "allow-events-pull-opened"
            }
        , viewCheckbox
            { title = "Synchronize"
            , subtitle = Nothing
            , field = "allow_pull_synchronize"
            , state = allowEvents.pull.synchronize
            , msg = msg { allowEvents = allowEvents, event = "allow_pull_synchronize" }
            , disabled_ = False
            , id_ = "allow-events-pull-synchronize"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_pull_edited"
            , state = allowEvents.pull.edited
            , msg = msg { allowEvents = allowEvents, event = "allow_pull_edited" }
            , disabled_ = False
            , id_ = "allow-events-pull-edited"
            }
        , viewCheckbox
            { title = "Reopened"
            , subtitle = Nothing
            , field = "allow_pull_reopened"
            , state = allowEvents.pull.reopened
            , msg = msg { allowEvents = allowEvents, event = "allow_pull_reopened" }
            , disabled_ = False
            , id_ = "allow-events-pull-reopened"
            }
        ]
    , strong [ class "settings-subtitle" ] [ text "Deployments" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_deploy_created"
            , state = allowEvents.deploy.created
            , msg = msg { allowEvents = allowEvents, event = "allow_deploy_created" }
            , disabled_ = False
            , id_ = "allow-events-deploy-created"
            }
        ]
    , strong [ class "settings-subtitle" ] [ text "Comment" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_comment_created"
            , state = allowEvents.comment.created
            , msg = msg { allowEvents = allowEvents, event = "allow_comment_created" }
            , disabled_ = False
            , id_ = "allow-events-comment-created"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_comment_edited"
            , state = allowEvents.comment.edited
            , msg = msg { allowEvents = allowEvents, event = "allow_comment_edited" }
            , disabled_ = False
            , id_ = "allow-events-comment-edited"
            }
        ]
    , strong [ class "settings-subtitle" ] [ text "Delete" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Branch"
            , subtitle = Nothing
            , field = "allow_push_delete_branch"
            , state = allowEvents.push.deleteBranch
            , msg = msg { allowEvents = allowEvents, event = "allow_push_delete_branch" }
            , disabled_ = False
            , id_ = "allow-events-push-delete-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_delete_tag"
            , state = allowEvents.push.deleteTag
            , msg = msg { allowEvents = allowEvents, event = "allow_push_delete_tag" }
            , disabled_ = False
            , id_ = "allow-events-push-delete-tag"
            }
        ]
    , strong [ class "settings-subtitle" ] [ text "Schedule" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Schedule"
            , subtitle = Nothing
            , field = "allow_schedule_run"
            , state = allowEvents.schedule.run
            , msg = msg { allowEvents = allowEvents, event = "allow_schedule_run" }
            , disabled_ = False
            , id_ = "allow-events-schedule-run"
            }
        ]
    ]
