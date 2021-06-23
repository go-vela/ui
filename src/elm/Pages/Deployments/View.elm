{--
Copyright (c) 2021 Target Brands, Inc. All rights reserved.
Use of this source code is governed by the LICENSE file in this repository.
--}


module Pages.Deployments.View exposing (addDeployment, addForm)

import Html
    exposing
        ( Html
        , a
        , button
        , div
        , h2
        , span
        , td
        , text
        , tr
        )
import Html.Attributes
    exposing
        ( attribute
        , class
        , scope
        )
import Html.Events exposing (onClick)
import Pages.Deployments.Form exposing (viewHelp, viewTargetInput, viewParameterInput, viewSubmitButtons, viewValueInput)
import Pages.Deployments.Model
    exposing
        ( Model
        , Msg(..)
        , PartialModel
        )

import Util exposing (largeLoader)


-- ADD SECRET
{-| addDeployment : takes partial model and renders the Add Deployment form
-}
addDeployment : PartialModel a msg -> Html Msg
addDeployment model =
    div [ class "manage-secret", Util.testAttribute "manage-secret" ]
        [ div []
            [ addForm model.deploymentModel
            ]
        ]

{-| addForm : renders secret update form for adding a new secret
-}
addForm : Model msg -> Html Msg
addForm deploymentModel =
    let
        deployment =
            deploymentModel.form
    in
    div [ class "secret-form" ]
        [ viewTargetInput deployment.target False
        , viewValueInput "Ref" deployment.ref "provide the reference to deploy - this can be a branch, commit (SHA) or tag (default: \"refs/heads/master\")"
        , viewValueInput "Description" deployment.description "provide the description for the deployment (default: \"Deployment request from Vela\")"
        , viewParameterInput deployment
        , viewSubmitButtons deploymentModel
        , viewHelp
        ]
