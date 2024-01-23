module Components.SecretEdit exposing (..)

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
import RemoteData exposing (WebData)
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
    , secret : WebData Vela.Secret
    , type_ : Vela.SecretType
    , value : String
    , events : List String
    , images : List String
    , image : String
    , allowCommands : Bool
    , teamInput : Maybe (Html msg)
    }



-- VIEW


view : Shared.Model -> Props msg -> Html msg
view shared props =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ h2 [] [ viewFormHeader props.type_ ]
            , div [ class "secret-form" ]
                [ Maybe.Extra.unwrap (text "") (\t -> t) props.teamInput

                -- todo: convert this into a select form that uses list of secrets as input
                , Components.Form.viewInput
                    { name = "Name"
                    , val = RemoteData.unwrap "" .name props.secret
                    , placeholder_ = "loading..."
                    , className = "Secret Name"
                    , disabled_ = True
                    , msg = props.msgs.nameOnInput
                    }
                , Components.Form.viewTextarea
                    { name = "Value"
                    , val = props.value
                    , placeholder_ = RemoteData.unwrap "loading..." (\_ -> "<leave blank to make no change to the value>") props.secret
                    , className = "Secret Value"
                    , disabled_ = not <| RemoteData.isSuccess props.secret
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
                            , disabled_ = not <| RemoteData.isSuccess props.secret
                            }
                        , Components.Form.viewRadio
                            { value = Util.boolToYesNo props.allowCommands
                            , field = "no"
                            , title = "No"
                            , msg = props.msgs.allowCommandsOnClick "no"
                            , disabled_ = not <| RemoteData.isSuccess props.secret
                            }
                        ]
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
                    , disabled <| not <| RemoteData.isSuccess props.secret
                    ]
                    [ text "Update" ]
                ]
            ]
        ]


viewFormHeader : Vela.SecretType -> Html msg
viewFormHeader type_ =
    case type_ of
        Vela.OrgSecret ->
            text "Edit Org Secret"

        Vela.RepoSecret ->
            text "Edit Repo Secret"

        Vela.SharedSecret ->
            text "Edit Shared Secret"


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
                , disabled_ = not <| RemoteData.isSuccess props.secret
                }
            , Components.Form.viewCheckbox
                { name = "Pull Request"
                , field = "pull_request"
                , state = List.member "pull_request" props.events
                , msg = props.msgs.eventOnCheck "pull_request"
                , disabled_ = not <| RemoteData.isSuccess props.secret
                }
            , Components.Form.viewCheckbox
                { name = "Tag"
                , field = "tag"
                , state = List.member "tag" props.events
                , msg = props.msgs.eventOnCheck "tag"
                , disabled_ = not <| RemoteData.isSuccess props.secret
                }
            , Components.Form.viewCheckbox
                { name = "Comment"
                , field = "comment"
                , state = List.member "comment" props.events
                , msg = props.msgs.eventOnCheck "comment"
                , disabled_ = not <| RemoteData.isSuccess props.secret
                }
            , Components.Form.viewCheckbox
                { name = "Deployment"
                , field = "deployment"
                , state = List.member "deployment" props.events
                , msg = props.msgs.eventOnCheck "deployment"
                , disabled_ = not <| RemoteData.isSuccess props.secret
                }
            , if schedulesAllowed then
                Components.Form.viewCheckbox
                    { name = "Schedule"
                    , field = "schedule"
                    , state = List.member "schedule" props.events
                    , msg = props.msgs.eventOnCheck "schedule"
                    , disabled_ = not <| RemoteData.isSuccess props.secret
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
                , disabled <| not <| RemoteData.isSuccess props.secret
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
