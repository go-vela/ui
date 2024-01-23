module Components.Form exposing (..)

import Html exposing (Html, div, input, label, section, strong, text, textarea)
import Html.Attributes exposing (checked, class, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Utils.Helpers as Util



-- VIEW


viewInput : { name : String, val : String, placeholder_ : String, className : String, disabled_ : Bool, msg : String -> msg } -> Html msg
viewInput { name, val, placeholder_, className, disabled_, msg } =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| name ]
            [ strong [] [ text name ] ]
        , input
            [ disabled disabled_
            , value val
            , onInput msg
            , class className
            , placeholder placeholder_
            , id name
            ]
            []
        ]


viewTextarea : { name : String, val : String, placeholder_ : String, className : String, disabled_ : Bool, msg : String -> msg } -> Html msg
viewTextarea { name, val, placeholder_, className, disabled_, msg } =
    section [ class "form-control", class "-stack" ]
        [ label
            [ class "form-label"
            , for name
            ]
            [ strong [] [ text name ] ]
        , textarea
            [ disabled disabled_
            , value val
            , onInput msg
            , class className
            , class "form-control"
            , rows 2
            , wrap "soft"
            , placeholder placeholder_
            , id name
            ]
            []
        ]


viewCheckbox : { name : String, field : String, state : Bool, disabled_ : Bool, msg : Bool -> msg } -> Html msg
viewCheckbox { name, field, state, disabled_, msg } =
    div
        [ class "form-control"
        , Util.testAttribute <| "checkbox-" ++ field
        ]
        [ input
            [ type_ "checkbox"
            , id <| "checkbox-" ++ field
            , checked state
            , disabled disabled_
            , onCheck msg
            ]
            []
        , label [ class "form-label", for <| "checkbox-" ++ field ]
            [ text name ]
        ]


viewRadio : { value : String, field : String, title : String, disabled_ : Bool, msg : msg } -> Html msg
viewRadio { value, field, title, disabled_, msg } =
    div [ class "form-control", Util.testAttribute <| "radio-" ++ field ]
        [ input
            [ type_ "radio"
            , id <| "radio-" ++ field
            , checked (value == field)
            , disabled disabled_
            , onClick msg
            ]
            []
        , label [ class "form-label", for <| "radio-" ++ field ]
            [ strong [] [ text title ] ]
        ]
