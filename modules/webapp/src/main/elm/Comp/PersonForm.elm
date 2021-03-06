module Comp.PersonForm exposing
    ( Model
    , Msg(..)
    , emptyModel
    , getPerson
    , isValid
    , update
    , view
    , view1
    , view2
    )

import Api.Model.IdName exposing (IdName)
import Api.Model.Person exposing (Person)
import Comp.AddressForm
import Comp.Basic as B
import Comp.ContactField
import Comp.Dropdown
import Comp.FixedDropdown
import Data.DropdownStyle as DS
import Data.Flags exposing (Flags)
import Data.PersonUse exposing (PersonUse)
import Data.UiSettings exposing (UiSettings)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onInput)
import Styles as S


type alias Model =
    { person : Person
    , name : String
    , addressModel : Comp.AddressForm.Model
    , contactModel : Comp.ContactField.Model
    , notes : Maybe String
    , use : PersonUse
    , useModel : Comp.FixedDropdown.Model PersonUse
    , orgModel : Comp.Dropdown.Model IdName
    }


emptyModel : Model
emptyModel =
    { person = Api.Model.Person.empty
    , name = ""
    , addressModel = Comp.AddressForm.emptyModel
    , contactModel = Comp.ContactField.emptyModel
    , notes = Nothing
    , use = Data.PersonUse.Both
    , useModel =
        Comp.FixedDropdown.initMap
            Data.PersonUse.label
            Data.PersonUse.all
    , orgModel = Comp.Dropdown.orgDropdown
    }


isValid : Model -> Bool
isValid model =
    model.name /= ""


getPerson : Model -> Person
getPerson model =
    let
        person =
            model.person

        org =
            Comp.Dropdown.getSelected model.orgModel
                |> List.head
    in
    { person
        | name = model.name
        , address = Comp.AddressForm.getAddress model.addressModel
        , contacts = Comp.ContactField.getContacts model.contactModel
        , notes = model.notes
        , use = Data.PersonUse.asString model.use
        , organization = org
    }


type Msg
    = SetName String
    | SetPerson Person
    | AddressMsg Comp.AddressForm.Msg
    | ContactMsg Comp.ContactField.Msg
    | SetNotes String
    | SetOrgs (List IdName)
    | OrgDropdownMsg (Comp.Dropdown.Msg IdName)
    | UseDropdownMsg (Comp.FixedDropdown.Msg PersonUse)


update : Flags -> Msg -> Model -> ( Model, Cmd Msg )
update flags msg model =
    case msg of
        SetPerson t ->
            let
                ( m1, c1 ) =
                    update flags (AddressMsg (Comp.AddressForm.SetAddress t.address)) model

                ( m2, c2 ) =
                    update flags (ContactMsg (Comp.ContactField.SetItems t.contacts)) m1

                ( m3, c3 ) =
                    update flags
                        (OrgDropdownMsg
                            (Comp.Dropdown.SetSelection
                                (List.filterMap identity [ t.organization ])
                            )
                        )
                        m2
            in
            ( { m3
                | person = t
                , name = t.name
                , notes = t.notes
                , use =
                    Data.PersonUse.fromString t.use
                        |> Maybe.withDefault Data.PersonUse.Both
              }
            , Cmd.batch [ c1, c2, c3 ]
            )

        SetOrgs orgs ->
            let
                opts =
                    Comp.Dropdown.SetOptions orgs
            in
            update flags (OrgDropdownMsg opts) model

        AddressMsg am ->
            let
                ( m1, c1 ) =
                    Comp.AddressForm.update am model.addressModel
            in
            ( { model | addressModel = m1 }, Cmd.map AddressMsg c1 )

        ContactMsg m ->
            let
                ( m1, c1 ) =
                    Comp.ContactField.update m model.contactModel
            in
            ( { model | contactModel = m1 }, Cmd.map ContactMsg c1 )

        SetName n ->
            ( { model | name = n }, Cmd.none )

        SetNotes str ->
            ( { model
                | notes =
                    if str == "" then
                        Nothing

                    else
                        Just str
              }
            , Cmd.none
            )

        UseDropdownMsg lm ->
            let
                ( nm, mu ) =
                    Comp.FixedDropdown.update lm model.useModel

                newUse =
                    Maybe.withDefault model.use mu
            in
            ( { model | useModel = nm, use = newUse }, Cmd.none )

        OrgDropdownMsg lm ->
            let
                ( dm_, cmd_ ) =
                    Comp.Dropdown.update lm model.orgModel
            in
            ( { model | orgModel = dm_ }
            , Cmd.map OrgDropdownMsg cmd_
            )


view : UiSettings -> Model -> Html Msg
view settings model =
    view1 settings False model


view1 : UiSettings -> Bool -> Model -> Html Msg
view1 settings compact model =
    div [ class "ui form" ]
        [ div
            [ classList
                [ ( "field", True )
                , ( "error", not (isValid model) )
                ]
            ]
            [ label [] [ text "Name*" ]
            , input
                [ type_ "text"
                , onInput SetName
                , placeholder "Name"
                , value model.name
                ]
                []
            ]
        , div [ class "field" ]
            [ label [] [ text "Use" ]
            , Html.map UseDropdownMsg (Comp.FixedDropdown.view (makeUseItem model) model.useModel)
            , label [] [ text "Use for concerning person suggestion only" ]
            ]
        , div [ class "field" ]
            [ label [] [ text "Organization" ]
            , Html.map OrgDropdownMsg (Comp.Dropdown.view settings model.orgModel)
            ]
        , h3 [ class "ui dividing header" ]
            [ text "Address"
            ]
        , Html.map AddressMsg (Comp.AddressForm.view settings model.addressModel)
        , h3 [ class "ui dividing header" ]
            [ text "Contacts"
            ]
        , Html.map ContactMsg (Comp.ContactField.view1 settings compact model.contactModel)
        , h3 [ class "ui dividing header" ]
            [ text "Notes"
            ]
        , div [ class "field" ]
            [ textarea
                [ onInput SetNotes
                , Maybe.withDefault "" model.notes |> value
                ]
                []
            ]
        ]


makeUseItem : Model -> Maybe (Comp.FixedDropdown.Item PersonUse)
makeUseItem model =
    Just <|
        Comp.FixedDropdown.Item model.use (Data.PersonUse.label model.use)



--- View2


view2 : Bool -> UiSettings -> Model -> Html Msg
view2 mobile settings model =
    div [ class "flex flex-col" ]
        [ div
            [ class "mb-4"
            ]
            [ label
                [ class S.inputLabel
                , for "personname"
                ]
                [ text "Name"
                , B.inputRequired
                ]
            , input
                [ type_ "text"
                , onInput SetName
                , placeholder "Name"
                , value model.name
                , class S.textInput
                , classList
                    [ ( S.inputErrorBorder, not (isValid model) )
                    ]
                , name "personname"
                ]
                []
            ]
        , div [ class "mb-4" ]
            [ label
                [ class S.inputLabel
                ]
                [ text "Use of this person" ]
            , Html.map UseDropdownMsg
                (Comp.FixedDropdown.view2 (makeUseItem model) model.useModel)
            , span [ class "opacity-50 text-sm" ]
                [ case model.use of
                    Data.PersonUse.Concerning ->
                        text "Use as concerning person only"

                    Data.PersonUse.Correspondent ->
                        text "Use as correspondent person only"

                    Data.PersonUse.Both ->
                        text "Use as both concerning or correspondent person"
                ]
            ]
        , div [ class "mb-4" ]
            [ label
                [ class S.inputLabel
                ]
                [ text "Organization"
                ]
            , Html.map OrgDropdownMsg
                (Comp.Dropdown.view2
                    DS.mainStyle
                    settings
                    model.orgModel
                )
            ]
        , div [ class "mb-4" ]
            [ h3 [ class "ui dividing header" ]
                [ text "Address"
                ]
            , Html.map AddressMsg (Comp.AddressForm.view2 settings model.addressModel)
            ]
        , div [ class "mb-4" ]
            [ h3 [ class S.header3 ]
                [ text "Contacts"
                ]
            , Html.map ContactMsg
                (Comp.ContactField.view2 mobile settings model.contactModel)
            ]
        , div [ class "mb-4" ]
            [ h3 [ class S.header3 ]
                [ text "Notes"
                ]
            , div [ class "" ]
                [ textarea
                    [ onInput SetNotes
                    , Maybe.withDefault "" model.notes |> value
                    , class S.textAreaInput
                    ]
                    []
                ]
            ]
        ]
