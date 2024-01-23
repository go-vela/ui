module Components.SecretAdd exposing (..)

import Components.Form
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , div
        , em
        , h2
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
import Maybe.Extra
import Shared
import Utils.Helpers as Util
import Vela



-- TYPES


type alias Msgs msg =
    { nameOnInput : String -> msg
    , valueOnInput : String -> msg
    , imageOnInput : String -> msg
    , eventOnCheck : String -> Bool -> msg
    , addImage : String -> msg
    , removeImage : String -> msg
    , allowCommandsOnClick : String -> msg
    , submit : msg
    , showCopyAlert : String -> msg
    }


type alias Props msg =
    { msgs : Msgs msg
    , type_ : Vela.SecretType
    , teamInput : Maybe (Html msg)
    , name : String
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommands : Bool
    }



-- VIEW


view : Shared.Model -> Props msg -> Html msg
view shared props =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ h2 [] [ viewFormHeader props.type_ ]
            , div [ class "secret-form" ]
                [ Maybe.Extra.unwrap (text "") (\t -> t) props.teamInput
                , Components.Form.viewInput
                    { name = "Name"
                    , val = props.name
                    , placeholder_ = "secret-name"
                    , className = "Secret Name"
                    , disabled_ = False
                    , msg = props.msgs.nameOnInput
                    }
                , Components.Form.viewTextarea
                    { name = "Value"
                    , val = props.value
                    , placeholder_ = "secret-value"
                    , className = "Secret Value"
                    , disabled_ = False
                    , msg = props.msgs.valueOnInput
                    }
                , viewEventsSelect shared props
                , viewImagesInput props
                , section [ Util.testAttribute "allow-commands" ]
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
                            { value = Util.boolToYesNo props.allowCommands
                            , field = "yes"
                            , title = "Yes"
                            , msg = props.msgs.allowCommandsOnClick "yes"
                            , disabled_ = False
                            }
                        , Components.Form.viewRadio
                            { value = Util.boolToYesNo props.allowCommands
                            , field = "no"
                            , title = "No"
                            , msg = props.msgs.allowCommandsOnClick "no"
                            , disabled_ = False
                            }
                        ]
                    ]
                , div [ class "help" ]
                    [ text "Need help? Visit our "
                    , a
                        [ href "https://go-vela.github.io/docs/tour/secrets/"
                        , target "_blank"
                        ]
                        [ text "docs" ]
                    , text "!"
                    ]
                , div [ class "form-action" ]
                    [ button
                        [ class "button"
                        , class "-outline"
                        , onClick props.msgs.submit
                        ]
                        [ text "Add" ]
                    ]
                ]
            ]
        ]


viewFormHeader : Vela.SecretType -> Html msg
viewFormHeader type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Add Org Secret"

        Vela.RepoSecret ->
            text "Add Repo Secret"

        Vela.SharedSecret ->
            text "Add Shared Secret"


viewEventsSelect : Shared.Model -> Props msg -> Html msg
viewEventsSelect shared props =
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
                , state = List.member "push" props.events
                , msg = props.msgs.eventOnCheck "push"
                , disabled_ = False
                }
            , Components.Form.viewCheckbox
                { name = "Pull Request"
                , field = "pull_request"
                , state = List.member "pull_request" props.events
                , msg = props.msgs.eventOnCheck "pull_request"
                , disabled_ = False
                }
            , Components.Form.viewCheckbox
                { name = "Tag"
                , field = "tag"
                , state = List.member "tag" props.events
                , msg = props.msgs.eventOnCheck "tag"
                , disabled_ = False
                }
            , Components.Form.viewCheckbox
                { name = "Comment"
                , field = "comment"
                , state = List.member "comment" props.events
                , msg = props.msgs.eventOnCheck "comment"
                , disabled_ = False
                }
            , Components.Form.viewCheckbox
                { name = "Deployment"
                , field = "deployment"
                , state = List.member "deployment" props.events
                , msg = props.msgs.eventOnCheck "deployment"
                , disabled_ = False
                }
            , if schedulesAllowed then
                Components.Form.viewCheckbox
                    { name = "Schedule"
                    , field = "schedule"
                    , state = List.member "schedule" props.events
                    , msg = props.msgs.eventOnCheck "schedule"
                    , disabled_ = False
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


viewImagesInput : Props msg -> Html msg
viewImagesInput props =
    section [ class "image" ]
        [ div [ id "images-select", class "form-control", class "-stack" ]
            [ label [ for "images-select", class "form-label" ]
                [ strong [] [ text "Limit to Docker Images" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Leave blank to enable this secret for all images)" ]
                    ]
                ]
            , input
                [ placeholder "Image Name"
                , onInput <| props.msgs.imageOnInput
                , value props.image
                ]
                []
            , button
                [ class "button"
                , class "-outline"
                , class "add-image"
                , onClick <| props.msgs.addImage <| String.toLower props.image
                , disabled <| String.isEmpty <| String.trim props.image
                ]
                [ text "Add Image"
                ]
            ]
        , div [ class "images" ] <| viewAddedImages props
        ]


viewAddedImages : Props msg -> List (Html msg)
viewAddedImages props =
    if List.length props.images > 0 then
        List.map (viewAddedImage props) <| List.reverse props.images

    else
        viewNoImages


viewNoImages : List (Html msg)
viewNoImages =
    [ div [ class "added-image" ]
        [ div [ class "name" ] [ code [] [ text "enabled for all images" ] ]

        -- add button to match style
        , button
            [ class "button"
            , class "-outline"
            , class "visually-hidden"
            , disabled True
            ]
            [ text "remove"
            ]
        ]
    ]


viewAddedImage : Props msg -> String -> Html msg
viewAddedImage props image =
    div [ class "added-image", class "chevron" ]
        [ div [ class "name" ] [ text image ]
        , button
            [ class "button"
            , class "-outline"
            , onClick <| props.msgs.removeImage image
            ]
            [ text "remove"
            ]
        ]
