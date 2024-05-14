{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Form exposing (viewAllowEvents, viewButton, viewCheckbox, viewInput, viewRadio, viewSubtitle, viewTextarea)

import Html exposing (Html, button, div, h3, input, label, section, span, strong, text, textarea)
import Html.Attributes exposing (checked, class, classList, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Maybe.Extra
import Shared
import Utils.Helpers as Util
import Vela



-- VIEW


{-| viewInput : renders the HTML for an input field.
-}
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
    let
        target =
            String.join "-" [ "input", id_ ]
    in
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for target ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , input
            [ id target
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Util.testAttribute target
            ]
            []
        ]


{-| viewTextarea : renders the HTML for a text area field.
-}
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
    let
        target =
            String.join "-" [ "textarea", id_ ]
    in
    section
        [ class "form-control"
        , class "-stack"
        ]
        [ Maybe.Extra.unwrap (text "")
            (\l ->
                label [ class "form-label", for target ]
                    [ strong [] [ text l ], viewSubtitle subtitle ]
            )
            title
        , textarea
            [ id target
            , value val
            , placeholder placeholder_
            , classList classList_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            , disabled disabled_
            , Util.testAttribute target
            ]
            []
        ]


{-| viewCheckbox : renders the HTML for a checkbox.
-}
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
    let
        target =
            String.join "-" [ "checkbox", id_, field ]
    in
    div
        [ class "form-control"
        , Util.testAttribute target
        ]
        [ input
            [ type_ "checkbox"
            , id target
            , checked state
            , onCheck msg
            , disabled disabled_
            , Util.testAttribute id_
            ]
            []
        , label [ class "form-label", for target ]
            [ text title, viewSubtitle subtitle ]
        ]


{-| viewRadio : renders the HTML for a radio button.
-}
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
    let
        target =
            String.join "-" [ "radio", id_ ]
    in
    div [ class "form-control", Util.testAttribute target ]
        [ input
            [ type_ "radio"
            , id target
            , checked (value == field)
            , onClick msg
            , disabled disabled_
            , Util.testAttribute target
            ]
            []
        , label [ class "form-label", for target ]
            [ strong [] [ text title ], viewSubtitle subtitle ]
        ]


{-| viewButton : renders the HTML for a button.
-}
viewButton : { id_ : String, msg : msg, text_ : String, classList_ : List ( String, Bool ), disabled_ : Bool } -> Html msg
viewButton { id_, msg, text_, classList_, disabled_ } =
    let
        target =
            String.join "-" [ "button", id_ ]
    in
    button
        [ class "button"
        , onClick msg
        , disabled disabled_
        , classList classList_
        , Util.testAttribute target
        ]
        [ text text_ ]


{-| viewSubtitle : renders the HTML for a subtitle.
-}
viewSubtitle : Maybe (Html msg) -> Html msg
viewSubtitle subtitle =
    Maybe.Extra.unwrap (text "")
        (\s -> span [] [ text " ", s ])
        subtitle


{-| viewAllowEvents : takes in allowed events and renders the HTML for events.
-}
viewAllowEvents :
    Shared.Model
    ->
        { msg : { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } -> Bool -> msg
        , allowEvents : Vela.AllowEvents
        , disabled_ : Bool
        }
    -> List (Html msg)
viewAllowEvents shared { msg, allowEvents } =
    [ h3 [ class "settings-subtitle" ] [ text "Push" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Push"
            , subtitle = Nothing
            , field = "allow_push_branch"
            , state = allowEvents.push.branch
            , msg = msg { allowEvents = allowEvents, event = Vela.PushBranch }
            , disabled_ = False
            , id_ = "allow-events-push-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_tag"
            , state = allowEvents.push.tag
            , msg = msg { allowEvents = allowEvents, event = Vela.PushTag }
            , disabled_ = False
            , id_ = "allow-events-push-tag"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Pull Request" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Opened"
            , subtitle = Nothing
            , field = "allow_pull_opened"
            , state = allowEvents.pull.opened
            , msg = msg { allowEvents = allowEvents, event = Vela.PullOpened }
            , disabled_ = False
            , id_ = "allow-events-pull-opened"
            }
        , viewCheckbox
            { title = "Synchronize"
            , subtitle = Nothing
            , field = "allow_pull_synchronize"
            , state = allowEvents.pull.synchronize
            , msg = msg { allowEvents = allowEvents, event = Vela.PullSynchronize }
            , disabled_ = False
            , id_ = "allow-events-pull-synchronize"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_pull_edited"
            , state = allowEvents.pull.edited
            , msg = msg { allowEvents = allowEvents, event = Vela.PullEdited }
            , disabled_ = False
            , id_ = "allow-events-pull-edited"
            }
        , viewCheckbox
            { title = "Reopened"
            , subtitle = Nothing
            , field = "allow_pull_reopened"
            , state = allowEvents.pull.reopened
            , msg = msg { allowEvents = allowEvents, event = Vela.PullReopened }
            , disabled_ = False
            , id_ = "allow-events-pull-reopened"
            }
        , viewCheckbox
            { title = "Labeled"
            , subtitle = Nothing
            , field = "allow_pull_labeled"
            , state = allowEvents.pull.labeled
            , msg = msg { allowEvents = allowEvents, event = Vela.PullLabeled }
            , disabled_ = False
            , id_ = "allow-events-pull-labeled"
            }
        , viewCheckbox
            { title = "Unlabeled"
            , subtitle = Nothing
            , field = "allow_pull_unlabeled"
            , state = allowEvents.pull.unlabeled
            , msg = msg { allowEvents = allowEvents, event = Vela.PullUnlabeled }
            , disabled_ = False
            , id_ = "allow-events-pull-unlabeled"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Deployments" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_deploy_created"
            , state = allowEvents.deploy.created
            , msg = msg { allowEvents = allowEvents, event = Vela.DeployCreated }
            , disabled_ = False
            , id_ = "allow-events-deploy-created"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Comment" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Created"
            , subtitle = Nothing
            , field = "allow_comment_created"
            , state = allowEvents.comment.created
            , msg = msg { allowEvents = allowEvents, event = Vela.CommentCreated }
            , disabled_ = False
            , id_ = "allow-events-comment-created"
            }
        , viewCheckbox
            { title = "Edited"
            , subtitle = Nothing
            , field = "allow_comment_edited"
            , state = allowEvents.comment.edited
            , msg = msg { allowEvents = allowEvents, event = Vela.CommentEdited }
            , disabled_ = False
            , id_ = "allow-events-comment-edited"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Delete" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Branch"
            , subtitle = Nothing
            , field = "allow_push_delete_branch"
            , state = allowEvents.push.deleteBranch
            , msg = msg { allowEvents = allowEvents, event = Vela.PushDeleteBranch }
            , disabled_ = False
            , id_ = "allow-events-push-delete-branch"
            }
        , viewCheckbox
            { title = "Tag"
            , subtitle = Nothing
            , field = "allow_push_delete_tag"
            , state = allowEvents.push.deleteTag
            , msg = msg { allowEvents = allowEvents, event = Vela.PushDeleteTag }
            , disabled_ = False
            , id_ = "allow-events-push-delete-tag"
            }
        ]
    , h3 [ class "settings-subtitle" ] [ text "Schedule" ]
    , div [ class "form-controls", class "-two-col" ]
        [ viewCheckbox
            { title = "Schedule"
            , subtitle = Nothing
            , field = "allow_schedule_run"
            , state = allowEvents.schedule.run
            , msg = msg { allowEvents = allowEvents, event = Vela.ScheduleRun }
            , disabled_ = False
            , id_ = "allow-events-schedule-run"
            }
        ]
    ]
