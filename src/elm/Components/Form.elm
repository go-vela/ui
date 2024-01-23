module Components.Form exposing (..)

import Html exposing (Html, div, input, label, section, strong, text, textarea)
import Html.Attributes exposing (checked, class, classList, disabled, for, id, placeholder, rows, type_, value, wrap)
import Html.Events exposing (onCheck, onClick, onInput)
import Maybe.Extra
import Utils.Helpers as Util



-- VIEW


viewInput :
    { name : String
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , disabled_ : Bool
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    }
    -> Html msg
viewInput { name, val, placeholder_, classList_, disabled_, rows_, wrap_, msg } =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| name ]
            [ strong [] [ text name ] ]
        , input
            [ id name
            , value val
            , placeholder placeholder_
            , classList classList_
            , disabled disabled_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
            ]
            []
        ]


viewTextarea :
    { name : String
    , val : String
    , placeholder_ : String
    , classList_ : List ( String, Bool )
    , disabled_ : Bool
    , rows_ : Maybe Int
    , wrap_ : Maybe String
    , msg : String -> msg
    }
    -> Html msg
viewTextarea { name, val, placeholder_, classList_, disabled_, rows_, wrap_, msg } =
    section [ class "form-control", class "-stack" ]
        [ label
            [ class "form-label"
            , for name
            ]
            [ strong [] [ text name ] ]
        , textarea
            [ id name
            , value val
            , placeholder placeholder_
            , classList classList_
            , disabled disabled_
            , Maybe.Extra.unwrap Util.attrNone rows rows_
            , Maybe.Extra.unwrap Util.attrNone wrap wrap_
            , onInput msg
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
