{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments.Add exposing (Model, Msg, page, view)

import Auth
import Components.Form
import Dict
import Effect exposing (Effect)
import Html exposing (Html, button, code, div, em, h2, label, section, span, strong, text)
import Html.Attributes exposing (class, disabled, for, id)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Shared
import String.Extra
import Url
import Utils.Helpers as Util
import Vela
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { org : String, repo : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared route
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { utilButtons = []
        , navButtons = []
        }



-- INIT


type alias Model =
    { repo : WebData Vela.Repository
    , target : String
    , ref : String
    , description : String
    , task : String
    , parameterKey : String
    , parameterValue : String
    , parameters : List Vela.KeyValuePair
    }


init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    ( { repo = RemoteData.Loading
      , target = Maybe.withDefault "" <| Dict.get "target" route.query
      , ref = Maybe.withDefault "" <| Dict.get "ref" route.query
      , description = Maybe.withDefault "" <| Dict.get "description" route.query
      , task = Maybe.withDefault "" <| Dict.get "task" route.query
      , parameterKey = ""
      , parameterValue = ""
      , parameters =
            Dict.get "parameters" route.query
                |> Maybe.withDefault ""
                |> String.split ","
                |> List.map Url.percentDecode
                |> List.filterMap identity
                |> List.map (String.split "=")
                |> List.map
                    (\d ->
                        case d of
                            key :: value :: [] ->
                                Just { key = key, value = value }

                            _ ->
                                Nothing
                    )
                |> List.filterMap identity
      }
    , Effect.getRepo
        { baseUrl = shared.velaAPI
        , session = shared.session
        , onResponse = GetRepoResponse
        , org = route.params.org
        , repo = route.params.repo
        }
    )



-- UPDATE


type Msg
    = GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
    | AddDeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Deployment ))
    | TargetOnInput String
    | RefOnInput String
    | DescriptionOnInput String
    | TaskOnInput String
    | ParameterKeyOnInput String
    | ParameterValueOnInput String
    | AddParameter
    | RemoveParameter Vela.KeyValuePair
    | SubmitForm
    | AddAlertCopiedToClipboard String
    | OnQueryParamChanged { from : Maybe String, to : Maybe String }


update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        OnQueryParamChanged _ ->
            ( model, Effect.none )

        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        AddDeploymentResponse response ->
            case response of
                Ok ( _, deployment ) ->
                    ( model
                    , Effect.addAlertSuccess
                        { content = "Added deployment for commit " ++ deployment.commit ++ "."
                        , addToastIfUnique = True
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError { httpError = error }
                    )

        TargetOnInput val ->
            ( { model | target = val }
            , Effect.none
            )

        RefOnInput val ->
            ( { model | ref = val }
            , Effect.none
            )

        DescriptionOnInput val ->
            ( { model | description = val }
            , Effect.none
            )

        TaskOnInput val ->
            ( { model | task = val }
            , Effect.none
            )

        ParameterKeyOnInput val ->
            ( { model | parameterKey = val }
            , Effect.none
            )

        ParameterValueOnInput val ->
            ( { model | parameterValue = val }
            , Effect.none
            )

        AddParameter ->
            ( { model
                | parameterKey = ""
                , parameterValue = ""
                , parameters = { key = model.parameterKey, value = model.parameterValue } :: model.parameters
              }
            , Effect.none
            )

        RemoveParameter parameter ->
            ( { model
                | parameters = List.Extra.remove parameter model.parameters
              }
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    Vela.buildDeploymentPayload
                        { org = Just route.params.org
                        , repo = Just route.params.repo
                        , commit = Nothing
                        , description = Just model.description
                        , ref =
                            Just <|
                                if String.trim model.target == "" then
                                    RemoteData.unwrap "main" .branch model.repo

                                else
                                    model.ref
                        , target =
                            Just <|
                                if String.trim model.target == "" then
                                    "production"

                                else
                                    model.target
                        , task = Just model.task
                        , payload = Just model.parameters
                        }

                body =
                    Http.jsonBody <| Vela.encodeDeploymentPayload payload
            in
            ( model
            , Effect.addDeployment
                { baseUrl = shared.velaAPI
                , session = shared.session
                , onResponse = AddDeploymentResponse
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        AddAlertCopiedToClipboard contentCopied ->
            ( model
            , Effect.addAlertSuccess { content = contentCopied, addToastIfUnique = False }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    { title = "Add Deployment"
    , body =
        [ div [ class "manage-deployment", Util.testAttribute "manage-deployment" ]
            [ div []
                [ h2 [] [ text <| String.Extra.toTitleCase <| "add deployment" ]
                , div [ class "deployment-form" ]
                    [ case model.repo of
                        RemoteData.Success repo ->
                            if not repo.allow_deploy then
                                section [ class "notice" ]
                                    [ strong []
                                        [ text "Deploy webhook for this repo must be enabled in settings"
                                        ]
                                    ]

                            else
                                text ""

                        _ ->
                            text ""
                    , Components.Form.viewTextarea
                        { title = Just "Target"
                        , subtitle = Nothing
                        , id_ = "target"
                        , val = model.target
                        , placeholder_ = "provide the name for the target deployment environment (default: \"production\")"
                        , classList_ = [ ( "secret-value", True ) ]
                        , disabled_ = False
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = TargetOnInput
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Ref"
                        , subtitle = Nothing
                        , id_ = "ref"
                        , val = model.ref
                        , placeholder_ =
                            "provide the reference to deploy - this can be a branch, commit (SHA) or tag\n(default is your repo's default branch: "
                                ++ RemoteData.unwrap "main" .branch model.repo
                                ++ ")"
                        , classList_ = [ ( "secret-value", True ) ]
                        , disabled_ = False
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = RefOnInput
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Description"
                        , subtitle = Nothing
                        , id_ = "description"
                        , val = model.description
                        , placeholder_ = "provide the description for the deployment (default: \"Deployment request from Vela\")"
                        , classList_ = [ ( "secret-value", True ) ]
                        , disabled_ = False
                        , rows_ = Just 5
                        , wrap_ = Just "soft"
                        , msg = DescriptionOnInput
                        }
                    , Components.Form.viewTextarea
                        { title = Just "Task"
                        , subtitle = Nothing
                        , id_ = "task"
                        , val = model.task
                        , placeholder_ = "Provide the task for the deployment (default: \"deploy:vela\")"
                        , classList_ = [ ( "secret-value", True ) ]
                        , disabled_ = False
                        , rows_ = Just 2
                        , wrap_ = Just "soft"
                        , msg = TaskOnInput
                        }
                    , viewParametersInput model
                    , div [ class "help" ]
                        [ text "Need help? Visit our "
                        , Html.a
                            [ Html.Attributes.href "https://go-vela.github.io/docs/usage/deployments/"
                            , Html.Attributes.target "_blank"
                            ]
                            [ text "docs" ]
                        , text "!"
                        ]
                    , div [ class "buttons" ]
                        [ div [ class "form-action" ]
                            [ button
                                [ class "button"
                                , class "-outline"
                                , onClick SubmitForm
                                ]
                                [ text "Submit" ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }


viewParametersInput : Model -> Html Msg
viewParametersInput model =
    section []
        [ div
            [ id "parameter-select"
            , class "form-control"
            , class "-stack"
            , class "parameters-container"
            ]
            [ label
                [ for "parameter-select"
                , class "form-label"
                ]
                [ strong [] [ text "Add Parameters" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Optional)" ]
                    ]
                ]
            , div [ class "parameters-inputs" ]
                [ Components.Form.viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = "parameter-key"
                    , val = model.parameterKey
                    , placeholder_ = "key"
                    , classList_ = [ ( "parameter-input", True ) ]
                    , disabled_ = False
                    , rows_ = Just 2
                    , wrap_ = Just "soft"
                    , msg = ParameterKeyOnInput
                    }
                , Components.Form.viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = "parameter-value"
                    , val = model.parameterValue
                    , placeholder_ = "value"
                    , classList_ = [ ( "parameter-input", True ) ]
                    , disabled_ = False
                    , rows_ = Just 2
                    , wrap_ = Just "soft"
                    , msg = ParameterValueOnInput
                    }
                , button
                    [ class "button"
                    , class "-outline"
                    , class "add-parameter"
                    , onClick <| AddParameter
                    , Util.testAttribute "add-parameter-button"
                    , disabled <| String.length model.parameterKey == 0 || String.length model.parameterValue == 0
                    ]
                    [ text "Add"
                    ]
                ]
            ]
        , div [ class "parameters", Util.testAttribute "parameters-list" ] <|
            if List.length model.parameters > 0 then
                List.map viewParameter <| List.reverse model.parameters

            else
                [ div [ class "no-parameters" ]
                    [ div
                        [ class "none"
                        ]
                        [ code [] [ text "no parameters defined" ] ]
                    ]
                ]
        ]


viewParameter : Vela.KeyValuePair -> Html Msg
viewParameter parameter =
    div [ class "parameter", class "chevron" ]
        [ button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveParameter parameter
            ]
            [ text "remove"
            ]
        , div [ class "name" ] [ text (parameter.key ++ "=" ++ parameter.value) ]
        ]
