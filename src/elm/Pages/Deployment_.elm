module Pages.Deployment_ exposing (..)

import Dict exposing (Dict)
import Effect exposing (Effect)
import Favorites exposing (ToggleFavorite, starToggle)
import FeatherIcons
import Html
    exposing
        ( Html
        , a
        , button
        , code
        , details
        , div
        , em
        , h1
        , input
        , label
        , p
        , section
        , span
        , strong
        , summary
        , td
        , text
        , textarea
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , disabled
        , for
        , href
        , id
        , placeholder
        , rows
        , scope
        , target
        , value
        , wrap
        )
import Html.Events exposing (onClick, onInput)
import Http
import List
import List.Extra
import Page exposing (Page)
import RemoteData exposing (RemoteData(..), WebData)
import Route exposing (Route)
import Routes
import Search
    exposing
        ( homeSearchBar
        , toLowerContains
        )
import Shared
import Svg.Attributes
import SvgBuilder
import Table
import Util
import Vela exposing (Deployment, Favorites, KeyValuePair, Org, Repo, Repository, Team)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view shared
        }



-- INIT


type alias Model =
    { org : Org
    , repo : Repo
    , team : Team
    , form : Form
    , repo_settings : WebData Repository
    }


{-| Form : record to hold potential deployment fields
-}
type alias Form =
    { commit : String
    , description : String
    , payload : List KeyValuePair
    , ref : String
    , target : String
    , task : String
    , parameterInputKey : String
    , parameterInputValue : String
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { org = ""
      , repo = ""
      , team = ""
      , form =
            { commit = ""
            , description = ""
            , payload = []
            , ref = ""
            , target = ""
            , task = ""
            , parameterInputKey = ""
            , parameterInputValue = ""
            }
      , repo_settings = NotAsked
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = NoOp
    | OnChangeStringField String String
    | AddParameter Form
    | RemoveParameter KeyValuePair
    | AddDeployment


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model
            , Effect.none
            )

        OnChangeStringField _ _ ->
            ( model
            , Effect.none
            )

        AddParameter _ ->
            ( model
            , Effect.none
            )

        RemoveParameter _ ->
            ( model
            , Effect.none
            )

        AddDeployment ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


{-| view : takes current user, user input and action params and renders home page with favorited repos
-}
view : Shared.Model -> Model -> View Msg
view shared model =
    let
        body =
            div [ Util.testAttribute "template_" ] <|
                case shared.user of
                    Success u ->
                        [ text "loaded shared.user" ]

                    Loading ->
                        [ h1 [] [ text "Loading user...", span [ class "loading-ellipsis" ] [] ] ]

                    NotAsked ->
                        [ text "not asked" ]

                    Failure _ ->
                        [ text "failed" ]
    in
    { title = "Pages.Template_"
    , body =
        [ body
        ]
    }



-- ADD DEPLOYMENT


{-| addDeployment : takes partial model and renders the Add Deployment form
-}
addDeployment : Model -> Html Msg
addDeployment model =
    div [ class "manage-deployment", Util.testAttribute "add-deployment" ]
        [ div []
            [ addForm model
            ]
        ]


{-| addForm : renders deployment form for adding a new deployment
-}
addForm : Model -> Html Msg
addForm model =
    let
        form =
            model.form

        branch =
            case model.repo_settings of
                RemoteData.Success repo ->
                    repo.branch

                _ ->
                    ""
    in
    div [ class "deployment-form" ]
        [--     h2 [ class "deployment-header" ] [ text "Add Deployment" ]
         -- , viewDeployEnabled deploymentModel.repo_settings
         -- -- GitHub default is "production". If we support more SCMs, this line may need tweaking
         -- , viewValueInput "Target" deployment.target "provide the name for the target deployment environment (default: \"production\")"
         -- , viewValueInput "Ref" deployment.ref <| "provide the reference to deploy - this can be a branch, commit (SHA) or tag (default: " ++ branch ++ ")"
         -- , viewValueInput "Description" deployment.description "provide the description for the deployment (default: \"Deployment request from Vela\")"
         -- , viewValueInput "Task" deployment.task "Provide the task for the deployment (default: \"deploy:vela\")"
         -- , viewParameterInput deployment
         -- , viewHelp
         -- , viewSubmitButtons
        ]


{-| viewAddedParameters : renders added parameters
-}
viewAddedParameters : List KeyValuePair -> List (Html Msg)
viewAddedParameters parameters =
    if List.length parameters > 0 then
        List.map addedParameter <| List.reverse parameters

    else
        noParameters


{-| noParameters : renders when no parameters have been added
-}
noParameters : List (Html Msg)
noParameters =
    [ div [ class "added-parameter" ]
        [ div [ class "name" ] [ code [] [ text "No Parameters defined" ] ]

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


{-| addedParameter : renders added parameter
-}
addedParameter : KeyValuePair -> Html Msg
addedParameter parameter =
    div [ class "added-parameter", class "chevron" ]
        [ div [ class "name" ] [ text (parameter.key ++ "=" ++ parameter.value) ]
        , button
            [ class "button"
            , class "-outline"
            , onClick <| RemoveParameter parameter
            ]
            [ text "remove"
            ]
        ]


{-| viewHelp : renders help msg pointing to Vela docs
-}
viewHelp : Html Msg
viewHelp =
    div [ class "help" ] [ text "Need help? Visit our ", a [ href deploymentDocsURL, target "_blank" ] [ text "docs" ], text "!" ]


{-| viewValueInput : renders value input box
-}
viewValueInput : String -> String -> String -> Html Msg
viewValueInput name val placeholder_ =
    section [ class "form-control", class "-stack" ]
        [ label [ class "form-label", for <| name ] [ strong [] [ text name ] ]
        , textarea
            [ value val
            , onInput <| OnChangeStringField name
            , class "parameter-value"
            , class "form-control"
            , rows 2
            , wrap "soft"
            , placeholder placeholder_
            , id name
            ]
            []
        ]


{-| viewDeployEnabled : displays a message to enable Deploy webhook if it is not enabled
-}
viewDeployEnabled : WebData Repository -> Html Msg
viewDeployEnabled repo_settings =
    case repo_settings of
        RemoteData.Success repo ->
            if repo.allow_deploy then
                section []
                    []

            else
                section [ class "notice" ]
                    [ strong [] [ text "Deploy webhook for this repo must be enabled in settings" ]
                    ]

        _ ->
            section [] []


{-| viewParameterInput : renders parameters input box and parameters
-}
viewParameterInput : Form -> Html Msg
viewParameterInput form =
    section [ class "parameter" ]
        [ div [ id "parameter-select", class "form-control", class "-stack" ]
            [ label [ for "parameter-select", class "form-label" ]
                [ strong [] [ text "Add Parameters" ]
                , span
                    [ class "field-description" ]
                    [ em [] [ text "(Optional)" ]
                    ]
                ]
            , input
                [ placeholder "Key"
                , class "parameter-input"
                , Util.testAttribute "parameter-key-input"
                , onInput <| OnChangeStringField "parameterInputKey"
                , value form.parameterInputKey
                ]
                []
            , input
                [ placeholder "Value"
                , class "parameter-input"
                , Util.testAttribute "parameter-value-input"
                , onInput <| OnChangeStringField "parameterInputValue"
                , value form.parameterInputValue
                ]
                []
            , button
                [ class "button"
                , Util.testAttribute "add-parameter-button"
                , class "-outline"
                , class "add-paramter"
                , onClick <| AddParameter <| form
                , disabled <| String.length form.parameterInputKey * String.length form.parameterInputValue == 0
                ]
                [ text "Add"
                ]
            ]
        , div [ class "parameters", Util.testAttribute "parameters-list" ] <| viewAddedParameters form.payload
        ]


viewSubmitButtons : Html Msg
viewSubmitButtons =
    div [ class "buttons" ]
        [ viewUpdateButton
        ]


viewUpdateButton : Html Msg
viewUpdateButton =
    button
        [ class "button"
        , Util.testAttribute "add-deployment-button"

        -- , onClick <| Pages.Deployments.Model.AddDeployment
        ]
        [ text "Add Deployment" ]


deploymentDocsURL : String
deploymentDocsURL =
    "https://go-vela.github.io/docs/usage/deployments/"
