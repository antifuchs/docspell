module Comp.CustomFieldForm exposing
    ( Model
    , Msg
    , ViewSettings
    , fullViewSettings
    , init
    , initEmpty
    , makeField
    , update
    , view
    , view2
    )

import Api
import Api.Model.BasicResult exposing (BasicResult)
import Api.Model.CustomField exposing (CustomField)
import Api.Model.NewCustomField exposing (NewCustomField)
import Comp.Basic as B
import Comp.FixedDropdown
import Comp.MenuBar as MB
import Comp.YesNoDimmer
import Data.CustomFieldType exposing (CustomFieldType)
import Data.DropdownStyle as DS
import Data.Flags exposing (Flags)
import Data.Validated exposing (Validated)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http
import Styles as S
import Util.Http
import Util.Maybe


type alias Model =
    { result : Maybe BasicResult
    , field : CustomField
    , name : Maybe String
    , label : Maybe String
    , ftype : Maybe CustomFieldType
    , ftypeModel : Comp.FixedDropdown.Model CustomFieldType
    , loading : Bool
    , deleteDimmer : Comp.YesNoDimmer.Model
    }


type Msg
    = SetName String
    | SetLabel String
    | FTypeMsg (Comp.FixedDropdown.Msg CustomFieldType)
    | RequestDelete
    | DeleteMsg Comp.YesNoDimmer.Msg
    | UpdateResp (Result Http.Error BasicResult)
    | GoBack
    | SubmitForm


init : CustomField -> Model
init field =
    { result = Nothing
    , field = field
    , name = Util.Maybe.fromString field.name
    , label = field.label
    , ftype = Data.CustomFieldType.fromString field.ftype
    , ftypeModel =
        Comp.FixedDropdown.initMap Data.CustomFieldType.label
            Data.CustomFieldType.all
    , loading = False
    , deleteDimmer = Comp.YesNoDimmer.emptyModel
    }


initEmpty : Model
initEmpty =
    init Api.Model.CustomField.empty



--- Update


makeField : Model -> Validated NewCustomField
makeField model =
    let
        name =
            Maybe.map Data.Validated.Valid model.name
                |> Maybe.withDefault (Data.Validated.Invalid [ "A name is required." ] "")

        ftype =
            Maybe.map Data.CustomFieldType.asString model.ftype
                |> Maybe.map Data.Validated.Valid
                |> Maybe.withDefault (Data.Validated.Invalid [ "A field type is required." ] "")

        make n ft =
            NewCustomField n model.label ft
    in
    Data.Validated.map2 make name ftype


update : Flags -> Msg -> Model -> ( Model, Cmd Msg, Bool )
update flags msg model =
    case msg of
        GoBack ->
            ( model, Cmd.none, True )

        FTypeMsg lm ->
            let
                ( m2, sel ) =
                    Comp.FixedDropdown.update lm model.ftypeModel
            in
            ( { model | ftype = Util.Maybe.or [ sel, model.ftype ], ftypeModel = m2 }
            , Cmd.none
            , False
            )

        SetName str ->
            ( { model | name = Util.Maybe.fromString str }
            , Cmd.none
            , False
            )

        SetLabel str ->
            ( { model | label = Util.Maybe.fromString str }
            , Cmd.none
            , False
            )

        SubmitForm ->
            let
                newField =
                    makeField model
            in
            case newField of
                Data.Validated.Valid f ->
                    ( model
                    , if model.field.id == "" then
                        Api.postCustomField flags f UpdateResp

                      else
                        Api.putCustomField flags model.field.id f UpdateResp
                    , False
                    )

                Data.Validated.Invalid msgs _ ->
                    let
                        combined =
                            String.join "; " msgs
                    in
                    ( { model | result = Just (BasicResult False combined) }
                    , Cmd.none
                    , False
                    )

                Data.Validated.Unknown _ ->
                    ( model, Cmd.none, False )

        RequestDelete ->
            let
                ( dm, _ ) =
                    Comp.YesNoDimmer.update Comp.YesNoDimmer.activate model.deleteDimmer
            in
            ( { model | deleteDimmer = dm }, Cmd.none, False )

        DeleteMsg lm ->
            let
                ( dm, flag ) =
                    Comp.YesNoDimmer.update lm model.deleteDimmer

                cmd =
                    if flag then
                        Api.deleteCustomField flags model.field.id UpdateResp

                    else
                        Cmd.none
            in
            ( { model | deleteDimmer = dm }, cmd, False )

        UpdateResp (Ok r) ->
            ( { model | result = Just r }, Cmd.none, r.success )

        UpdateResp (Err err) ->
            ( { model | result = Just (BasicResult False (Util.Http.errorToString err)) }
            , Cmd.none
            , False
            )



--- View


type alias ViewSettings =
    { classes : String
    , showControls : Bool
    }


fullViewSettings : ViewSettings
fullViewSettings =
    { classes = "ui error form segment"
    , showControls = True
    }


view : ViewSettings -> Model -> Html Msg
view viewSettings model =
    let
        mkItem cft =
            Comp.FixedDropdown.Item cft (Data.CustomFieldType.label cft)
    in
    div [ class viewSettings.classes ]
        ([ Html.map DeleteMsg (Comp.YesNoDimmer.view model.deleteDimmer)
         , if model.field.id == "" then
            div []
                [ text "Create a new custom field."
                ]

           else
            div []
                [ text "Modify this custom field. Note that changing the format may "
                , text "result in invisible values in the ui, if they don't comply to the new format!"
                ]
         , div
            [ classList
                [ ( "ui message", True )
                , ( "invisible hidden", model.result == Nothing )
                , ( "error", Maybe.map .success model.result == Just False )
                , ( "success", Maybe.map .success model.result == Just True )
                ]
            ]
            [ Maybe.map .message model.result
                |> Maybe.withDefault ""
                |> text
            ]
         , div [ class "required field" ]
            [ label [] [ text "Name" ]
            , input
                [ type_ "text"
                , onInput SetName
                , model.name
                    |> Maybe.withDefault ""
                    |> value
                ]
                []
            , div [ class "small-info" ]
                [ text "The name uniquely identifies this field. It must be a valid "
                , text "identifier, not contain spaces or weird characters."
                ]
            ]
         , div [ class "required field" ]
            [ label [] [ text "Field Format" ]
            , Html.map FTypeMsg
                (Comp.FixedDropdown.view
                    (Maybe.map mkItem model.ftype)
                    model.ftypeModel
                )
            , div [ class "small-info" ]
                [ text "A field must have a format. Values are validated "
                , text "according to this format."
                ]
            ]
         , div [ class "field" ]
            [ label [] [ text "Label" ]
            , input
                [ type_ "text"
                , onInput SetLabel
                , model.label
                    |> Maybe.withDefault ""
                    |> value
                ]
                []
            , div [ class "small-info" ]
                [ text "The user defined label for this field. This is used to represent "
                , text "this field in the ui. If not present, the name is used."
                ]
            ]
         ]
            ++ (if viewSettings.showControls then
                    viewButtons model

                else
                    []
               )
        )


viewButtons : Model -> List (Html Msg)
viewButtons model =
    [ div [ class "ui divider" ] []
    , button
        [ class "ui primary button"
        , onClick SubmitForm
        ]
        [ text "Submit"
        ]
    , button
        [ class "ui button"
        , onClick GoBack
        ]
        [ text "Back"
        ]
    , button
        [ classList
            [ ( "ui red button", True )
            , ( "invisible hidden", model.field.id == "" )
            ]
        , onClick RequestDelete
        ]
        [ text "Delete"
        ]
    ]



--- View2


view2 : ViewSettings -> Model -> List (Html Msg)
view2 viewSettings model =
    let
        mkItem cft =
            Comp.FixedDropdown.Item cft (Data.CustomFieldType.label cft)

        dimmerSettings =
            Comp.YesNoDimmer.defaultSettings2 "Really delete this custom field?"
    in
    (if viewSettings.showControls then
        [ viewButtons2 model ]

     else
        []
    )
        ++ [ div
                [ class viewSettings.classes
                , class "flex flex-col md:relative"
                ]
                [ Html.map DeleteMsg
                    (Comp.YesNoDimmer.viewN
                        True
                        dimmerSettings
                        model.deleteDimmer
                    )
                , div
                    [ classList
                        [ ( "hidden", model.result == Nothing )
                        , ( S.errorMessage, Maybe.map .success model.result == Just False )
                        , ( S.successMessage, Maybe.map .success model.result == Just True )
                        ]
                    , class "my-2"
                    ]
                    [ Maybe.map .message model.result
                        |> Maybe.withDefault ""
                        |> text
                    ]
                , if model.field.id == "" then
                    div [ class "py-2 text-lg opacity-75" ]
                        [ text "Create a new custom field."
                        ]

                  else
                    div [ class "py-2 text-lg opacity-75" ]
                        [ text "Note that changing the format may "
                        , text "result in invisible values in the ui, if they don't comply to the new format!"
                        ]
                , div [ class "mb-4" ]
                    [ label
                        [ class S.inputLabel
                        , for "fieldname"
                        ]
                        [ text "Name"
                        , B.inputRequired
                        ]
                    , input
                        [ type_ "text"
                        , onInput SetName
                        , model.name
                            |> Maybe.withDefault ""
                            |> value
                        , class S.textInput
                        , classList
                            [ ( S.inputErrorBorder, model.name == Nothing )
                            ]
                        , id "fieldname"
                        ]
                        []
                    , div [ class "opacity-75 text-sm" ]
                        [ text "The name uniquely identifies this field. It must be a valid "
                        , text "identifier, not contain spaces or weird characters."
                        ]
                    ]
                , div
                    [ class "mb-4"
                    ]
                    [ label [ class S.inputLabel ]
                        [ text "Field Format"
                        , B.inputRequired
                        ]
                    , Html.map FTypeMsg
                        (Comp.FixedDropdown.viewStyled2
                            DS.mainStyle
                            (model.ftype == Nothing)
                            (Maybe.map mkItem model.ftype)
                            model.ftypeModel
                        )
                    , div [ class "opacity-75 text-sm" ]
                        [ text "A field must have a format. Values are validated "
                        , text "according to this format."
                        ]
                    ]
                , div [ class "mb-4" ]
                    [ label
                        [ class S.inputLabel
                        , for "fieldlabel"
                        ]
                        [ text "Label" ]
                    , input
                        [ type_ "text"
                        , onInput SetLabel
                        , model.label
                            |> Maybe.withDefault ""
                            |> value
                        , class S.textInput
                        , id "fieldlabel"
                        ]
                        []
                    , div [ class "opacity-75 text-sm" ]
                        [ text "The user defined label for this field. This is used to represent "
                        , text "this field in the ui. If not present, the name is used."
                        ]
                    ]
                ]
           ]


viewButtons2 : Model -> Html Msg
viewButtons2 model =
    MB.view
        { start =
            [ MB.PrimaryButton
                { tagger = SubmitForm
                , title = "Submit this form"
                , icon = Just "fa fa-save"
                , label = "Submit"
                }
            , MB.SecondaryButton
                { tagger = GoBack
                , title = "Back to list"
                , icon = Just "fa fa-arrow-left"
                , label = "Cancel"
                }
            ]
        , end =
            if model.field.id /= "" then
                [ MB.DeleteButton
                    { tagger = RequestDelete
                    , title = "Delete this field"
                    , icon = Just "fa fa-trash"
                    , label = "Delete"
                    }
                ]

            else
                []
        , rootClasses = "mb-4"
        }
