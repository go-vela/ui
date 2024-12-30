{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments.Add exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Nav
import Dict
import Effect exposing (Effect)
import Html exposing (a, button, code, div, em, h2, label, main_, p, section, span, strong, text)
import Html.Attributes exposing (class, disabled, for, href, id)
import Html.Events exposing (onClick)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import RemoteData exposing (WebData)
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Url
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultDeploymentPayload)
import View exposing (View)
import Components.Loading as Loading


{-| page : takes user, shared model, route, and returns an add deployment page.
-}
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


{-| toLayout : takes user, route, model, and passes a deployments page info to Layouts.
-}
toLayout : Auth.User -> Route { org : String, repo : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "Add Deployment"
              , content =
                    "vela add deployment --org "
                        ++ route.params.org
                        ++ " --repo "
                        ++ route.params.repo
              , docs = Just "deployment/add"
              }
            ]
        }



-- INIT


{-| Model : alias for a model object for an add deployment page.
-}
type alias Model =
    { repo : WebData Vela.Repository
    , target : String
    , ref : String
    , description : String
    , task : String
    , parameterKey : String
    , parameterValue : String
    , parameters : List Vela.KeyValuePair
    , config : WebData Vela.DeploymentConfig
    }


{-| init : takes shared model, route, and initializes add deployment page input arguments.
-}
init : Shared.Model -> Route { org : String, repo : String } -> () -> ( Model, Effect Msg )
init shared route () =
    let
        ref =
            "deployments"

        -- if String.trim model.ref == "" then
        --     RemoteData.unwrap "main" .branch model.repo
        -- else
        --     model.ref
    in
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
      , config = RemoteData.Loading
      }
    , Effect.batch
        [ Effect.getRepo
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetRepoResponse
            , org = route.params.org
            , repo = route.params.repo
            }
        , Effect.getDeploymentConfig
            { baseUrl = shared.velaAPIBaseURL
            , session = shared.session
            , onResponse = GetDeploymentConfigResponse
            , org = route.params.org
            , repo = route.params.repo
            , ref = Just ref
            }
        ]
    )



-- UPDATE


{-| Msg : custom type with possible messages.
-}
type Msg
    = --BROWSER
      OnQueryParamChanged { from : Maybe String, to : Maybe String }
      -- REPO
    | GetRepoResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Repository ))
      -- DEPLOYMENTS
    | AddDeploymentResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Deployment ))
    | GetDeploymentConfigResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.DeploymentConfig ))
    | TargetOnInput String
    | RefOnInput String
    | DescriptionOnInput String
    | TaskOnInput String
    | ParameterKeyOnInput String
    | ParameterValueOnInput String
    | AddParameter
    | RemoveParameter Vela.KeyValuePair
    | DeploymentConfigTargetOnToggle String
    | SubmitForm


{-| update : takes current models, route, message, and returns an updated model and effect.
-}
update : Shared.Model -> Route { org : String, repo : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    case msg of
        -- BROWSER
        OnQueryParamChanged _ ->
            ( model, Effect.none )

        -- REPO
        GetRepoResponse response ->
            case response of
                Ok ( _, repo ) ->
                    ( { model | repo = RemoteData.succeed repo }
                    , Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        -- DEPLOYMENTS
        AddDeploymentResponse response ->
            case response of
                Ok ( _, deployment ) ->
                    let
                        ref =
                            if String.trim model.ref == "" then
                                RemoteData.unwrap "main" .branch model.repo

                            else
                                model.ref
                    in
                    ( model
                    , Effect.batch
                        [ Effect.addAlertSuccess
                            { content = "Added deployment for ref " ++ ref ++ "."
                            , addToastIfUnique = True
                            , link = Nothing
                            }
                        , Effect.replacePath <|
                            Route.Path.Org__Repo__Deployments { org = route.params.org, repo = route.params.repo }
                        ]
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        GetDeploymentConfigResponse response ->
            case response of
                Ok ( _, config ) ->
                    ( { model | config = RemoteData.succeed config }
                    , if List.length config.targets > 0 then
                        Effect.addAlertSuccess
                            { content = "Found dynamic parameters for this deployment ref!"
                            , addToastIfUnique = True
                            , link = Nothing
                            }

                      else
                        Effect.none
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
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
                    { defaultDeploymentPayload
                        | org = Just route.params.org
                        , repo = Just route.params.repo
                        , commit = Nothing
                        , description = Just model.description
                        , ref =
                            Just <|
                                if String.trim model.ref == "" then
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
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddDeploymentResponse
                , org = route.params.org
                , repo = route.params.repo
                , body = body
                }
            )

        DeploymentConfigTargetOnToggle _ ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


{-| subscriptions : takes model and returns that there are no subscriptions.
-}
subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes models, route, and creates the html for an add deployment page.
-}
view : Shared.Model -> Route { org : String, repo : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home_ )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( route.params.repo, Just <| Route.Path.Org__Repo_ { org = route.params.org, repo = route.params.repo } )
            , ( "Deployments", Just <| Route.Path.Org__Repo__Deployments { org = route.params.org, repo = route.params.repo } )
            , ( "Add", Nothing )
            ]
    in
    { title = "Add Deployment"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "manage-deployment", Util.testAttribute "manage-deployment" ]
                [ div []
                    [ h2 [] [ text <| String.Extra.toTitleCase <| "add deployment" ]
                    , div [ class "deployment-form" ]
                        [ case model.repo of
                            RemoteData.Success repo ->
                                if not repo.allowEvents.deploy.created then
                                    p [ class "notice" ]
                                        [ strong []
                                            [ text "Deploy webhook for this repo must be enabled in settings"
                                            ]
                                        ]

                                else
                                    text ""

                            _ ->
                                text ""
                        , Components.Form.viewTextareaSection
                            { title = Just "Ref"
                            , subtitle = Nothing
                            , id_ = "ref"
                            , val = model.ref
                            , placeholder_ =
                                "Provide the reference to deploy - this can be a branch, commit (SHA) or tag\n(default is your repo's default branch: "
                                    ++ RemoteData.unwrap "main" .branch model.repo
                                    ++ ")"
                            , classList_ = [ ( "secret-value", True ) ]
                            , disabled_ = False
                            , rows_ = Just 3
                            , wrap_ = Just "soft"
                            , msg = RefOnInput
                            }
                        , Components.Form.viewTextareaSection
                            { title = Just "Description"
                            , subtitle = Nothing
                            , id_ = "description"
                            , val = model.description
                            , placeholder_ = "Provide the description for the deployment (default: \"Deployment request from Vela\")"
                            , classList_ = [ ( "secret-value", True ) ]
                            , disabled_ = False
                            , rows_ = Just 5
                            , wrap_ = Just "soft"
                            , msg = DescriptionOnInput
                            }
                        , case model.config of
                            RemoteData.Success config ->
                                if List.length config.targets > 0 then
                                    viewDeploymentConfigTarget config.targets "" DeploymentConfigTargetOnToggle

                                else
                                    Components.Form.viewTextareaSection
                                        { title = Just "Target"
                                        , subtitle = Nothing
                                        , id_ = "target"
                                        , val = model.target
                                        , placeholder_ = "Provide the name for the target deployment environment (default: \"production\")"
                                        , classList_ = [ ( "secret-value", True ) ]
                                        , disabled_ = False
                                        , rows_ = Just 2
                                        , wrap_ = Just "soft"
                                        , msg = TargetOnInput
                                        }

                            _ ->
                                Loading.viewSmallLoaderWithText "loading config..."
                        , Components.Form.viewTextareaSection
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
                        , section []
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
                                    [ Components.Form.viewInputSection
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
                                    , Components.Form.viewInputSection
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
                                        , onClick <| AddParameter
                                        , Util.testAttribute "button-parameter-add"
                                        , disabled <| String.length model.parameterKey == 0 || String.length model.parameterValue == 0
                                        ]
                                        [ text "Add"
                                        ]
                                    ]
                                ]
                            , div [ class "parameters", Util.testAttribute "parameters-list" ] <|
                                if List.length model.parameters > 0 then
                                    let
                                        viewParameter parameter =
                                            div [ class "parameter", class "chevron" ]
                                                [ div [ class "name" ] [ text (parameter.key ++ "=" ++ parameter.value) ]
                                                , button
                                                    [ class "button"
                                                    , class "-outline"
                                                    , onClick <| RemoveParameter parameter
                                                    ]
                                                    [ text "remove"
                                                    ]
                                                ]
                                    in
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
                        , div [ class "help" ]
                            [ text "Need help? Visit our "
                            , a
                                [ href <| shared.velaDocsURL ++ "/usage/deployments/"
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
                                    [ text "Add Deployment" ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]
    }


viewDeploymentConfigTarget : List String -> String -> (String -> Msg) -> Html.Html Msg
viewDeploymentConfigTarget targets current msg =
    section [ class "settings", Util.testAttribute "repo-settings-pipeline-type" ]
        [ Html.label [ class "form-label" ] [ Html.strong [] [ text "Target" ] ]
        , div
            [ class "form-controls", class "-stack" ]
          <|
            List.map
                (\target ->
                    Components.Form.viewRadio
                        { value = current
                        , field = "target"
                        , title = target
                        , subtitle = Nothing
                        , msg = msg target
                        , disabled_ = False
                        , id_ = "target"
                        }
                )
                targets
        ]



-- viewDeploymentConfigParameter : String -> Vela.DeploymentConfigParameter -> String -> (String -> String -> Msg) -> View Msg
-- viewDeploymentConfigParameter key param current msg =
--     section [ class "settings", Util.testAttribute "repo-settings-pipeline-type" ]
--         [ h2 [ class "settings-title" ] [ text param.name ]
--         , p [ class "settings-description" ] [ text param.description ]
--         , div [ class "form-controls", class "-stack" ]
--             List.map
--             (\option ->
--                 [ Components.Form.viewRadio
--                     { value = current
--                     , field = key
--                     , title = param.name
--                     , subtitle = Nothing
--                     , msg = msg param.name option
--                     , disabled_ = False
--                     , id_ = "type-yaml"
--                     }
--                 ]
--             )
--             param.options
--         ]
