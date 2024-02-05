{--
SPDX-License-Identifier: Apache-2.0
--}


module Components.Form exposing (..)

import Html exposing (Html, br, button, div, em, h2, h3, input, label, p, section, span, strong, text, textarea)
import Html.Attributes exposing (checked, class, classList, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Maybe.Extra
import Utils.Helpers as Util
import Vela



-- VIEW


viewInput :
    { title : Maybe String
    , subtitle : Maybe (Html msg)
    , id_ : String
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewInput { title, subtitle, id_, val, placeholder_, classList_, rows_, wrap_, msg, disabled_ } =
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
            ]
            []
        ]


viewTextarea :
    { title : Maybe String
    , subtitle : Maybe (Html msg)
    , id_ : String
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewTextarea { title, subtitle, id_, val, placeholder_, classList_, rows_, wrap_, msg, disabled_ } =
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
            ]
            []
        ]


viewCheckbox :
    { title : String
    , subtitle : Maybe (Html msg)
    , field : String
    , state : Bool
    , msg : Bool -> msg
    , disabled_ : Bool
    }
    -> Html msg
viewCheckbox { title, subtitle, field, state, msg, disabled_ } =
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
            ]
            []
        , label [ class "form-label", for <| "checkbox-" ++ field ]
            [ text title, viewSubtitle subtitle ]
        ]


viewRadio :
    { title : String
    , subtitle : Maybe (Html msg)
    , value : String
    , field : String
    , msg : msg
    , disabled_ : Bool
    }
    -> Html msg
viewRadio { title, subtitle, value, field, msg, disabled_ } =
    div [ class "form-control", Util.testAttribute <| "radio-" ++ field ]
        [ input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , onClick msg
            , disabled disabled_
            ]
            []
        , label [ class "form-label", for <| "radio-" ++ field ]
            [ strong [] [ text title ], viewSubtitle subtitle ]
        ]


viewSubtitle : Maybe (Html msg) -> Html msg
viewSubtitle subtitle =
    Maybe.Extra.unwrap (text "") (\s -> span [] [ text <| " ", s ]) subtitle


viewButton : { msg : msg, text_ : String, classList_ : List ( String, Bool ), disabled_ : Bool } -> Html msg
viewButton { msg, text_, classList_, disabled_ } =
    button
        [ class "button"
        , class "-outline"
        , onClick msg
        , disabled disabled_
        , classList classList_
        ]
        [ text text_ ]


{-| viewAllowEvents : takes model and repo and renders the settings category for updating repo webhook events
-}
viewAllowEvents :
    ({ a | allow_events : Maybe Vela.AllowEvents } -> String -> Bool -> msg)
    -> Maybe Vela.AllowEvents
    -> { a | allow_events : Maybe Vela.AllowEvents }
    -> List (Html msg)
viewAllowEvents msg allowEvents repo =
    case allowEvents of
        Just events ->
            [ div [ class "form-controls", class "-two-col" ]
                [ viewCheckbox
                    { title = "Push"
                    , subtitle = Nothing
                    , field = "allow_push_branch"
                    , state = events.push.branch
                    , msg = msg repo "allow_push_branch"
                    , disabled_ = False
                    }
                , viewCheckbox
                    { title = "Tag"
                    , subtitle = Nothing
                    , field = "allow_push_tag"
                    , state = events.push.tag
                    , msg = msg repo "allow_push_tag"
                    , disabled_ = False
                    }
                ]
            , h3 [ class "settings-subtitle" ] [ text "Pull Request" ]
            , div [ class "form-controls", class "-two-col" ]
                [ viewCheckbox
                    { title = "Opened"
                    , subtitle = Nothing
                    , field = "allow_pull_opened"
                    , state = events.pull.opened
                    , msg = msg repo "allow_pull_opened"
                    , disabled_ = False
                    }
                , viewCheckbox
                    { title = "Synchronize"
                    , subtitle = Nothing
                    , field = "allow_pull_synchronize"
                    , state = events.pull.synchronize
                    , msg = msg repo "allow_pull_synchronize"
                    , disabled_ = False
                    }
                , viewCheckbox
                    { title = "Edited"
                    , subtitle = Nothing
                    , field = "allow_pull_edited"
                    , state = events.pull.edited
                    , msg = msg repo "allow_pull_edited"
                    , disabled_ = False
                    }
                , viewCheckbox
                    { title = "Reopened"
                    , subtitle = Nothing
                    , field = "allow_pull_reopened"
                    , state = events.pull.reopened
                    , msg = msg repo "allow_pull_reopened"
                    , disabled_ = False
                    }
                ]
            , h3 [ class "settings-subtitle" ] [ text "Deployments" ]
            , div [ class "form-controls", class "-two-col" ]
                [ viewCheckbox
                    { title = "Created"
                    , subtitle = Nothing
                    , field = "allow_deploy_created"
                    , state = events.deploy.created
                    , msg = msg repo "allow_deploy_created"
                    , disabled_ = False
                    }
                ]
            , h3 [ class "settings-subtitle" ] [ text "Comment" ]
            , div [ class "form-controls", class "-two-col" ]
                [ viewCheckbox
                    { title = "Created"
                    , subtitle = Nothing
                    , field = "allow_comment_created"
                    , state = events.comment.created
                    , msg = msg repo "allow_comment_created"
                    , disabled_ = False
                    }
                , viewCheckbox
                    { title = "Edited"
                    , subtitle = Nothing
                    , field = "allow_comment_edited"
                    , state = events.comment.edited
                    , msg = msg repo "allow_comment_edited"
                    , disabled_ = False
                    }
                ]
            ]

        Nothing ->
            []
