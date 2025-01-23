{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Org_.Repo_.Deployments.Add exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Loading as Loading
import Components.Nav
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, button, code, div, em, h2, main_, p, section, small, span, strong, text)
import Html.Attributes exposing (class, disabled, href)
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
    , configParameters : Dict String String
    , dropDownDict : Dict String Bool
    }


{-| init : takes shared model, route, and initializes add deployment page input arguments.
-}
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
                |> List.filterMap Url.percentDecode
                |> List.map (String.split "=")
                |> List.filterMap
                    (\d ->
                        case d of
                            key :: value :: [] ->
                                Just { key = key, value = value }

                            _ ->
                                Nothing
                    )
      , config = RemoteData.Loading
      , configParameters = Dict.empty
      , dropDownDict = Dict.empty
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
            , ref = Nothing
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
    | CfgParameterValueOnInput String String
    | UpdateRef
    | AddConfigParameter String String
    | ToggleDropdown String
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
                    ( { model
                        | config = RemoteData.succeed config
                        , configParameters = Dict.fromList <| List.map (\( k, _ ) -> ( k, "" )) (Dict.toList config.parameters)
                        , dropDownDict = Dict.fromList <| List.map (\( k, _ ) -> ( k, False )) (Dict.toList config.parameters)
                      }
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
                    ( { model
                        | configParameters = Dict.empty
                        , dropDownDict = Dict.empty
                      }
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

        AddConfigParameter k val ->
            ( { model
                | configParameters = Dict.remove k model.configParameters
                , parameters = { key = k, value = val } :: model.parameters
              }
            , Effect.none
            )

        RemoveParameter parameter ->
            ( { model
                | parameters = List.Extra.remove parameter model.parameters
                , configParameters = Dict.insert parameter.key "" model.configParameters
                , dropDownDict = Dict.update parameter.key (\_ -> Just False) model.dropDownDict
              }
            , Effect.none
            )

        CfgParameterValueOnInput k val ->
            ( { model
                | configParameters = Dict.insert k val model.configParameters
                , dropDownDict = Dict.update k (\_ -> Just False) model.dropDownDict
              }
            , Effect.none
            )

        UpdateRef ->
            ( model
            , Effect.getDeploymentConfig
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = GetDeploymentConfigResponse
                , org = route.params.org
                , repo = route.params.repo
                , ref = Just model.ref
                }
            )

        ToggleDropdown key ->
            ( { model | dropDownDict = Dict.update key (\val -> Just <| Maybe.withDefault True <| Maybe.map not val) model.dropDownDict }
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultDeploymentPayload
                        | org = Just route.params.org
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
                            , focusOutFunc = Just UpdateRef
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
                            , focusOutFunc = Nothing
                            }
                        , case model.config of
                            RemoteData.Success config ->
                                if List.length config.targets > 0 then
                                    viewDeploymentConfigTarget config.targets model.target TargetOnInput

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
                                        , focusOutFunc = Nothing
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
                            , focusOutFunc = Nothing
                            }

                        -- show deployment config parameters if available
                        , case model.config of
                            RemoteData.Success config ->
                                if Dict.size model.configParameters > 0 then
                                    div []
                                        [ strong [] [ text "Add Config Parameters" ]
                                        , div [ class "parameters-inputs-list", Util.testAttribute "parameters-inputs-list" ]
                                            (Dict.toList model.configParameters
                                                |> List.concatMap
                                                    (\( key, value ) ->
                                                        case Dict.get key config.parameters of
                                                            Just param ->
                                                                [ viewDeploymentConfigParameter model key param ]

                                                            Nothing ->
                                                                []
                                                    )
                                            )
                                        ]

                                else
                                    text ""

                            _ ->
                                text ""

                        -- standard parameters
                        , strong [] [ text "Add Custom Parameters" ]
                        , div [ class "parameters-inputs", Util.testAttribute "parameters-inputs" ]
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
                                , min = Nothing
                                , max = Nothing
                                , required = False
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
                                , min = Nothing
                                , max = Nothing
                                , required = False
                                }
                            , button
                                [ class "button"
                                , class "-outline"
                                , onClick AddParameter
                                , Util.testAttribute "button-parameter-add"
                                , disabled (String.isEmpty model.parameterKey || String.isEmpty model.parameterValue)
                                ]
                                [ text "Add"
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
                        , div [ class "help" ]
                            [ text "Need help? Visit our "
                            , a
                                [ href <| shared.velaDocsURL ++ "/usage/deployments/"
                                ]
                                [ text "docs" ]
                            , text "!"
                            ]
                        , Components.Form.viewButton
                            { id_ = "submit"
                            , msg = SubmitForm
                            , text_ = "Add Deployment"
                            , classList_ = []
                            , disabled_ = False
                            }
                        ]
                    ]
                ]
            ]
        ]
    }


viewDeploymentConfigTarget : List String -> String -> (String -> Msg) -> Html Msg
viewDeploymentConfigTarget targets current msg =
    section [ class "settings", Util.testAttribute "deployment-config-target" ]
        [ Html.label [ class "form-label" ] [ Html.strong [] [ text "Target" ] ]
        , div
            [ class "form-controls", class "-stack" ]
          <|
            List.map
                (\target ->
                    Components.Form.viewRadio
                        { value = current
                        , field = target
                        , title = target
                        , subtitle = Nothing
                        , msg = msg target
                        , disabled_ = False
                        , id_ = target
                        }
                )
                targets
        ]


viewDeploymentConfigParameter : Model -> String -> Vela.DeploymentConfigParameter -> Html Msg
viewDeploymentConfigParameter mdl key param =
    let
        smallText =
            if param.description == "" then
                ""

            else
                "(" ++ param.description ++ ")"
    in
    if List.isEmpty param.options then
        div [ Util.testAttribute "parameters-item-wrap" ]
            (case param.type_ of
                Vela.Int_ ->
                    [ div [ class "parameters-inputs" ]
                        [ Components.Form.viewInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "parameter-key"
                            , val = key
                            , placeholder_ = key
                            , classList_ = [ ( "parameter-input", True ) ]
                            , wrapperClassList = []
                            , disabled_ = True
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ParameterKeyOnInput
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , Components.Form.viewNumberInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "parameter-value"
                            , val = mdl.configParameters |> Dict.get key |> Maybe.withDefault ""
                            , placeholder_ = "0"
                            , classList_ = [ ( "parameter-input", True ) ]
                            , wrapperClassList = []
                            , disabled_ = False
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = CfgParameterValueOnInput key
                            , min =
                                if param.min == -1 then
                                    Nothing

                                else
                                    Just param.min
                            , max =
                                if param.max == -1 then
                                    Nothing

                                else
                                    Just param.max
                            , required = param.required
                            }
                        , button
                            [ class "button"
                            , class "-outline"
                            , onClick <| AddConfigParameter key (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                            , Util.testAttribute "button-parameter-add"
                            , disabled <| String.isEmpty (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                            ]
                            [ text "Add"
                            ]
                        ]
                    , small []
                        [ em [] [ text smallText ] ]
                    ]

                Vela.Bool_ ->
                    [ div [ class "parameters-inputs" ]
                        [ Components.Form.viewInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "parameter-key"
                            , val = key
                            , placeholder_ = key
                            , classList_ = [ ( "parameter-input", True ) ]
                            , wrapperClassList = []
                            , disabled_ = True
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ParameterKeyOnInput
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , div [ class "custom-select-container", Util.testAttribute "custom-select" ]
                            [ div
                                [ class "custom-select-selected"
                                , Html.Events.onClick (ToggleDropdown key)
                                ]
                                [ text (mdl.configParameters |> Dict.get key |> Maybe.withDefault "Select an option") ]
                            , div
                                [ class "custom-select-options"
                                , class <|
                                    if mdl.dropDownDict |> Dict.get key |> Maybe.withDefault False then
                                        ""

                                    else
                                        "hidden"
                                ]
                                [ div
                                    [ class "custom-select-option"
                                    , Html.Attributes.value "True"
                                    , Html.Events.onClick (CfgParameterValueOnInput key "True")
                                    ]
                                    [ text "True" ]
                                , div
                                    [ class "custom-select-option"
                                    , Html.Attributes.value "False"
                                    , Html.Events.onClick (CfgParameterValueOnInput key "False")
                                    ]
                                    [ text "False" ]
                                ]
                            ]
                        , button
                            [ class "button"
                            , class "-outline"
                            , onClick <| AddConfigParameter key (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                            , Util.testAttribute "button-parameter-add"
                            , disabled <| String.isEmpty (Dict.get key mdl.configParameters |> Maybe.withDefault "")
                            ]
                            [ text "Add"
                            ]
                        ]
                    , small []
                        [ em [] [ text smallText ] ]
                    ]

                _ ->
                    [ div [ class "parameters-inputs" ]
                        [ Components.Form.viewInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "parameter-key"
                            , val = key
                            , placeholder_ = key
                            , classList_ = [ ( "parameter-input", True ) ]
                            , wrapperClassList = []
                            , disabled_ = True
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ParameterKeyOnInput
                            , min = Nothing
                            , max = Nothing
                            , required = False
                            }
                        , Components.Form.viewInput
                            { title = Nothing
                            , subtitle = Nothing
                            , id_ = "parameter-value"
                            , val = mdl.configParameters |> Dict.get key |> Maybe.withDefault ""
                            , placeholder_ = "value"
                            , classList_ = [ ( "parameter-input", True ) ]
                            , wrapperClassList = []
                            , disabled_ = False
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = CfgParameterValueOnInput key
                            , min =
                                if param.min == -1 then
                                    Nothing

                                else
                                    Just (String.fromInt param.min)
                            , max =
                                if param.max == -1 then
                                    Nothing

                                else
                                    Just (String.fromInt param.max)
                            , required = param.required
                            }
                        , button
                            [ class "button"
                            , class "-outline"
                            , onClick <| AddConfigParameter key (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                            , Util.testAttribute "button-parameter-add"
                            , disabled <| String.isEmpty (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                            ]
                            [ text "Add"
                            ]
                        ]
                    , small []
                        [ em [] [ text smallText ] ]
                    ]
            )

    else
        let
            selected =
                if String.isEmpty (mdl.configParameters |> Dict.get key |> Maybe.withDefault "") then
                    "Select an option"

                else
                    mdl.configParameters |> Dict.get key |> Maybe.withDefault ""

            arrow =
                if mdl.dropDownDict |> Dict.get key |> Maybe.withDefault False then
                    "▲"

                else
                    "▼"
        in
        div [ Util.testAttribute "parameters-item-wrap" ]
            [ div [ class "parameters-inputs" ]
                [ Components.Form.viewInput
                    { title = Nothing
                    , subtitle = Nothing
                    , id_ = "parameter-key"
                    , val = key
                    , placeholder_ = key
                    , classList_ = [ ( "parameter-input", True ) ]
                    , wrapperClassList = []
                    , disabled_ = True
                    , rows_ = Just 2
                    , wrap_ = Just "soft"
                    , msg = ParameterKeyOnInput
                    , min = Nothing
                    , max = Nothing
                    , required = False
                    }
                , div [ class "custom-select-container", Util.testAttribute "custom-select" ]
                    [ div
                        [ class "custom-select-selected"
                        , Html.Events.onClick (ToggleDropdown key)
                        ]
                        [ text selected
                        , span [ class "arrow" ] [ text arrow ]
                        ]
                    , div
                        [ class "custom-select-options"
                        , Util.testAttribute "custom-select-options"
                        , class <|
                            if mdl.dropDownDict |> Dict.get key |> Maybe.withDefault False then
                                ""

                            else
                                "hidden"
                        ]
                        (List.map
                            (\option ->
                                div
                                    [ class "custom-select-option"
                                    , Html.Attributes.value option
                                    , Html.Events.onClick (CfgParameterValueOnInput key option)
                                    ]
                                    [ text option ]
                            )
                            param.options
                        )
                    ]
                , button
                    [ class "button"
                    , class "-outline"
                    , onClick <| AddConfigParameter key (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                    , Util.testAttribute "button-parameter-add"
                    , disabled <| String.isEmpty (mdl.configParameters |> Dict.get key |> Maybe.withDefault "")
                    ]
                    [ text "Add"
                    ]
                ]
            , small []
                [ em [] [ text smallText ] ]
            ]
