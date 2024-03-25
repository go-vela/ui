{--
SPDX-License-Identifier: Apache-2.0
--}


module Pages.Secrets.Engine_.Org.Org_.Add exposing (Model, Msg, page, view)

import Auth
import Components.Crumbs
import Components.Form
import Components.Nav
import Components.SecretForm
import Effect exposing (Effect)
import Html exposing (div, h2, main_, text)
import Html.Attributes exposing (class)
import Http
import Http.Detailed
import Layouts
import List.Extra
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import String.Extra
import Utils.Errors as Errors
import Utils.Helpers as Util
import Vela exposing (defaultSecretPayload)
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { engine : String, org : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init shared
        , update = update shared route
        , subscriptions = subscriptions
        , view = view shared route
        }
        |> Page.withLayout (toLayout user route)



-- LAYOUT


toLayout : Auth.User -> Route { engine : String, org : String } -> Model -> Layouts.Layout Msg
toLayout user route model =
    Layouts.Default
        { helpCommands =
            [ { name = "Add Org Secret Help"
              , content = "vela add secret -h"
              , docs = Just "secret/add"
              }
            , { name = "Add Org Secret Example"
              , content =
                    "vela add secrets --secret.engine native --secret.type org --org "
                        ++ route.params.org
                        ++ " --name password --value vela --event push"
              , docs = Just "secret/add"
              }
            ]
        }



-- INIT


type alias Model =
    { form : Components.SecretForm.Form
    }


init : Shared.Model -> () -> ( Model, Effect Msg )
init shared () =
    ( { form = Components.SecretForm.defaultOrgRepoSecretForm }
    , Effect.none
    )



-- UPDATE


type Msg
    = -- SECRETS
      AddSecretResponse (Result (Http.Detailed.Error String) ( Http.Metadata, Vela.Secret ))
    | NameOnInput String
    | ValueOnInput String
    | ImageOnInput String
    | AddImage String
    | RemoveImage String
    | AllowCommandsOnClick String
    | AllowSubstitutionOnClick String
    | AllowEventsUpdate { allowEvents : Vela.AllowEvents, event : Vela.AllowEventsField } Bool
    | SubmitForm


update : Shared.Model -> Route { engine : String, org : String } -> Msg -> Model -> ( Model, Effect Msg )
update shared route msg model =
    let
        form =
            model.form
    in
    case msg of
        -- SECRETS
        AddSecretResponse response ->
            case response of
                Ok ( _, secret ) ->
                    ( { form = Components.SecretForm.defaultOrgRepoSecretForm }
                    , Effect.addAlertSuccess
                        { content = "Added org secret '" ++ secret.name ++ "'."
                        , addToastIfUnique = True
                        , link = Nothing
                        }
                    )

                Err error ->
                    ( model
                    , Effect.handleHttpError
                        { error = error
                        , shouldShowAlertFn = Errors.showAlertAlways
                        }
                    )

        NameOnInput val ->
            ( { model | form = { form | name = val } }
            , Effect.none
            )

        ValueOnInput val ->
            ( { model | form = { form | value = val } }
            , Effect.none
            )

        ImageOnInput val ->
            ( { model | form = { form | image = val } }
            , Effect.none
            )

        AddImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.append [ image ]
                                |> List.Extra.unique
                        , image = ""
                    }
              }
            , Effect.none
            )

        RemoveImage image ->
            ( { model
                | form =
                    { form
                        | images =
                            form.images
                                |> List.filter ((/=) image)
                    }
              }
            , Effect.none
            )

        AllowCommandsOnClick val ->
            ( { model
                | form =
                    { form
                        | allowCommand = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowSubstitutionOnClick val ->
            ( { model
                | form =
                    { form
                        | allowSubstitution = Util.yesNoToBool val
                    }
              }
            , Effect.none
            )

        AllowEventsUpdate options val ->
            ( { model
                | form =
                    Vela.setAllowEvents model.form options.event val
              }
            , Effect.none
            )

        SubmitForm ->
            let
                payload =
                    { defaultSecretPayload
                        | type_ = Just Vela.OrgSecret
                        , org = Just route.params.org
                        , repo = Just "*"
                        , team = Nothing
                        , name = Util.stringToMaybe form.name
                        , value = Util.stringToMaybe form.value
                        , allowEvents = Just form.allowEvents
                        , images = Just form.images
                        , allowCommand = Just form.allowCommand
                        , allowSubstitution = Just form.allowSubstitution
                    }

                body =
                    Http.jsonBody <| Vela.encodeSecretPayload payload
            in
            ( model
            , Effect.addOrgSecret
                { baseUrl = shared.velaAPIBaseURL
                , session = shared.session
                , onResponse = AddSecretResponse
                , engine = route.params.engine
                , org = route.params.org
                , body = body
                }
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- VIEW


view : Shared.Model -> Route { engine : String, org : String } -> Model -> View Msg
view shared route model =
    let
        crumbs =
            [ ( "Overview", Just Route.Path.Home )
            , ( route.params.org, Just <| Route.Path.Org_ { org = route.params.org } )
            , ( "Org Secrets", Just <| Route.Path.SecretsEngine_OrgOrg_ { org = route.params.org, engine = route.params.engine } )
            , ( "Add", Nothing )
            ]
    in
    { title = "Add Secret"
    , body =
        [ Components.Nav.view
            shared
            route
            { buttons = []
            , crumbs = Components.Crumbs.view route.path crumbs
            }
        , main_ [ class "content-wrap" ]
            [ div [ class "manage-secret", Util.testAttribute "manage-secret" ]
                [ div []
                    [ h2 [] [ text <| String.Extra.toTitleCase "add org secret" ]
                    , div [ class "secret-form" ]
                        [ Components.Form.viewInput
                            { title = Just "Name"
                            , subtitle = Nothing
                            , id_ = "name"
                            , val = model.form.name
                            , placeholder_ = "Secret Name"
                            , classList_ = [ ( "secret-name", True ) ]
                            , rows_ = Nothing
                            , wrap_ = Nothing
                            , msg = NameOnInput
                            , disabled_ = False
                            }
                        , Components.Form.viewTextarea
                            { title = Just "Value"
                            , subtitle = Nothing
                            , id_ = "value"
                            , val = model.form.value
                            , placeholder_ = "Secret Value"
                            , classList_ = [ ( "secret-value", True ) ]
                            , rows_ = Just 2
                            , wrap_ = Just "soft"
                            , msg = ValueOnInput
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowEventsSelect
                            shared
                            { msg = AllowEventsUpdate
                            , allowEvents = model.form.allowEvents
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewImagesInput
                            { onInput_ = ImageOnInput
                            , addImage = AddImage
                            , removeImage = RemoveImage
                            , images = model.form.images
                            , imageValue = model.form.image
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowCommandsInput
                            { msg = AllowCommandsOnClick
                            , value = model.form.allowCommand
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewAllowSubstitutionInput
                            { msg = AllowSubstitutionOnClick
                            , value = model.form.allowSubstitution
                            , disabled_ = False
                            }
                        , Components.SecretForm.viewHelp shared.velaDocsURL
                        , Components.Form.viewButton
                            { id_ = "submit"
                            , msg = SubmitForm
                            , text_ = "Add Secret"
                            , classList_ = []
                            , disabled_ = False
                            }
                        ]
                    ]
                ]
            ]
        ]
    }
