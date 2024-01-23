module Components.SecretForm exposing (..)

import Components.Form
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , em
        , input
        , label
        , p
        , section
        , span
        , strong
        , text
        )
import Html.Attributes
    exposing
        ( class
        , disabled
        , for
        , href
        , id
        , placeholder
        , target
        , value
        )
import Html.Events exposing (onClick, onInput)
import Shared
import Utils.Helpers as Util



-- VIEW


viewEventsSelect :
    Shared.Model
    ->
        { disabled_ : Bool
        , msg : String -> Bool -> msg
        , events : List String
        }
    -> Html msg
viewEventsSelect shared { disabled_, msg, events } =
    let
        schedulesAllowed =
            Util.checkScheduleAllowlist "org" "repo" shared.velaScheduleAllowlist
    in
    section []
        [ div [ for "events-select" ]
            [ strong [] [ text "Limit to Events" ]
            , span [ class "field-description" ]
                [ text "( "
                , em [] [ text "at least one event must be selected" ]
                , text " )"
                ]
            , viewPullRequestWarning
            ]
        , div
            [ class "form-controls"
            , class "-stack"
            ]
            [ Components.Form.viewCheckbox
                { name = "Push"
                , field = "push"
                , state = List.member "push" events
                , msg = msg "push"
                , disabled_ = disabled_
                }
            , Components.Form.viewCheckbox
                { name = "Pull Request"
                , field = "pull_request"
                , state = List.member "pull_request" events
                , msg = msg "pull_request"
                , disabled_ = disabled_
                }
            , Components.Form.viewCheckbox
                { name = "Tag"
                , field = "tag"
                , state = List.member "tag" events
                , msg = msg "tag"
                , disabled_ = disabled_
                }
            , Components.Form.viewCheckbox
                { name = "Comment"
                , field = "comment"
                , state = List.member "comment" events
                , msg = msg "comment"
                , disabled_ = disabled_
                }
            , Components.Form.viewCheckbox
                { name = "Deployment"
                , field = "deployment"
                , state = List.member "deployment" events
                , msg = msg "deployment"
                , disabled_ = disabled_
                }
            , if schedulesAllowed then
                Components.Form.viewCheckbox
                    { name = "Schedule"
                    , field = "schedule"
                    , state = List.member "schedule" events
                    , msg = msg "schedule"
                    , disabled_ = disabled_
                    }

              else
                text ""
            ]
        ]


viewPullRequestWarning : Html msg
viewPullRequestWarning =
    p [ class "notice" ]
        [ text "Disclaimer: Native secrets do NOT have the "
        , strong [] [ text "pull_request" ]
        , text " event enabled by default. This is intentional to help mitigate exposure via a pull request against the repo. You can override this behavior, at your own risk, for each secret."
        ]


viewImagesInput :
    { disabled_ : Bool
    , onInput_ : String -> msg
    , addImage : String -> msg
    , removeImage : String -> msg
    , images : List String
    , imageValue : String
    }
    -> Html msg
viewImagesInput { disabled_, onInput_, addImage, removeImage, images, imageValue } =
    section []
        [ div
            [ id "image-select"
            , class "form-control"
            , class "-stack"
            , class "images-container"
            ]
            [ label
                [ for "image-select"
                , class "form-label"
                ]
                [ strong [] [ text "Limit to Docker Images" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                    ]
                ]
            , div [ class "parameters-inputs" ]
                [ Components.Form.viewInput
                    { label_ = Nothing
                    , id_ = "image-name"
                    , val = imageValue
                    , placeholder_ = "Image Name"
                    , classList_ = [ ( "image-input", True ) ]
                    , disabled_ = disabled_
                    , rows_ = Just 2
                    , wrap_ = Just "soft"
                    , msg = onInput_
                    }
                , button
                    [ class "button"
                    , class "-outline"
                    , class "add-image"
                    , Util.testAttribute "add-image-button"
                    , onClick <| addImage <| String.toLower imageValue
                    , disabled <| String.isEmpty <| String.trim imageValue
                    ]
                    [ text "Add Image"
                    ]
                ]
            ]
        , div [ class "images", Util.testAttribute "images-list" ] <|
            if List.length images > 0 then
                List.map (\image -> viewImage { msg = removeImage, image = image }) <| List.reverse images

            else
                [ div [ class "no-images" ]
                    [ div
                        [ class "none"
                        ]
                        [ code [] [ text "enabled for all images" ]
                        ]
                    ]
                ]
        ]


viewImage : { msg : String -> msg, image : String } -> Html msg
viewImage { msg, image } =
    div [ class "image", class "chevron" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick <| msg image
            ]
            [ text "remove"
            ]
        , div [ class "name" ] [ text image ]
        ]


viewAllowCommandsInput : { msg : String -> msg, value : Bool } -> Html msg
viewAllowCommandsInput { msg, value } =
    section [ Util.testAttribute "allow-commands" ]
        [ div [ class "form-control" ]
            [ strong []
                [ text "Allow Commands"
                , span [ class "field-description" ]
                    [ text "( "
                    , em [] [ text "\"No\" will disable this secret in " ]
                    , code [] [ text "commands" ]
                    , text " )"
                    ]
                ]
            ]
        , div
            [ class "form-controls", class "-stack" ]
            [ Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "yes"
                , title = "Yes"
                , msg = msg "yes"
                , disabled_ = False
                }
            , Components.Form.viewRadio
                { value = Util.boolToYesNo value
                , field = "no"
                , title = "No"
                , msg = msg "no"
                , disabled_ = False
                }
            ]
        ]


viewHelp : Html msg
viewHelp =
    div [ class "help" ]
        [ text "Need help? Visit our "
        , a
            [ href "https://go-vela.github.io/docs/tour/secrets/"
            , target "_blank"
            ]
            [ text "docs" ]
        , text "!"
        ]


viewSubmitButton : { msg : msg } -> Html msg
viewSubmitButton { msg } =
    div [ class "form-action" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick msg
            ]
            [ text "Submit" ]
        ]
