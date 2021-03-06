package docspell.ftssolr

import cats.effect._
import cats.implicits._

import docspell.common._
import docspell.ftsclient.FtsMigration

import _root_.io.circe._
import _root_.io.circe.generic.semiauto._
import _root_.io.circe.syntax._
import org.http4s._
import org.http4s.circe._
import org.http4s.client.Client
import org.http4s.client.dsl.Http4sClientDsl

trait SolrSetup[F[_]] {

  def setupSchema: List[FtsMigration[F]]

}

object SolrSetup {
  private val solrEngine = Ident.unsafe("solr")

  def apply[F[_]: ConcurrentEffect](cfg: SolrConfig, client: Client[F]): SolrSetup[F] = {
    val dsl = new Http4sClientDsl[F] {}
    import dsl._

    new SolrSetup[F] {

      val url = (Uri.unsafeFromString(cfg.url.asString) / "schema")
        .withQueryParam("commitWithin", cfg.commitWithin.toString)

      def setupSchema: List[FtsMigration[F]] =
        List(
          FtsMigration[F](
            1,
            solrEngine,
            "Initialize",
            setupCoreSchema.map(_ => FtsMigration.Result.workDone)
          ),
          FtsMigration[F](
            3,
            solrEngine,
            "Add folder field",
            addFolderField.map(_ => FtsMigration.Result.workDone)
          ),
          FtsMigration[F](
            4,
            solrEngine,
            "Index all from database",
            FtsMigration.Result.indexAll.pure[F]
          ),
          FtsMigration[F](
            5,
            solrEngine,
            "Add content_fr field",
            addContentField(Language.French).map(_ => FtsMigration.Result.workDone)
          ),
          FtsMigration[F](
            6,
            solrEngine,
            "Index all from database",
            FtsMigration.Result.indexAll.pure[F]
          ),
          FtsMigration[F](
            7,
            solrEngine,
            "Add content_it field",
            addContentField(Language.Italian).map(_ => FtsMigration.Result.reIndexAll)
          ),
          FtsMigration[F](
            8,
            solrEngine,
            "Add content_es field",
            addContentField(Language.Spanish).map(_ => FtsMigration.Result.reIndexAll)
          ),
          FtsMigration[F](
            9,
            solrEngine,
            "Add more content fields",
            addMoreContentFields.map(_ => FtsMigration.Result.reIndexAll)
          )
        )

      def addFolderField: F[Unit] =
        addStringField(Field.folderId)

      def addMoreContentFields: F[Unit] = {
        val remain = List[Language](
          Language.Norwegian,
          Language.Romanian,
          Language.Swedish,
          Language.Finnish,
          Language.Danish,
          Language.Czech,
          Language.Dutch,
          Language.Portuguese,
          Language.Russian
        )
        remain.traverse(addContentField).map(_ => ())
      }

      def setupCoreSchema: F[Unit] = {
        val cmds0 =
          List(
            Field.id,
            Field.itemId,
            Field.collectiveId,
            Field.discriminator,
            Field.attachmentId
          )
            .traverse(addStringField)
        val cmds1 = List(
          Field.attachmentName,
          Field.content,
          Field.itemName,
          Field.itemNotes
        )
          .traverse(addTextField(None))

        val cntLang = List(Language.German, Language.English, Language.French).traverse {
          case l @ Language.German =>
            addTextField(l.some)(Field.content_de)
          case l @ Language.English =>
            addTextField(l.some)(Field.content_en)
          case l @ Language.French =>
            addTextField(l.some)(Field.content_fr)
          case _ =>
            ().pure[F]
        }

        cmds0 *> cmds1 *> cntLang *> ().pure[F]
      }

      private def run(cmd: Json): F[Unit] = {
        val req = Method.POST(cmd, url)
        client.expect[Unit](req)
      }

      private def addStringField(field: Field): F[Unit] =
        run(DeleteField.command(DeleteField(field))).attempt *>
          run(AddField.command(AddField.string(field)))

      private def addContentField(lang: Language): F[Unit] =
        addTextField(Some(lang))(Field.contentField(lang))

      private def addTextField(lang: Option[Language])(field: Field): F[Unit] =
        lang match {
          case None =>
            run(DeleteField.command(DeleteField(field))).attempt *>
              run(AddField.command(AddField.textGeneral(field)))
          case Some(lang) =>
            run(DeleteField.command(DeleteField(field))).attempt *>
              run(AddField.command(AddField.textLang(field, lang)))
        }
    }
  }

  // Schema Commands: The structure is for conveniently creating the
  // solr json. All fields must be stored, because of highlighting and
  // single-updates only work when all fields are stored.

  case class AddField(
      name: Field,
      `type`: String,
      stored: Boolean,
      indexed: Boolean,
      multiValued: Boolean
  )
  object AddField {
    implicit val encoder: Encoder[AddField] =
      deriveEncoder[AddField]

    def command(body: AddField): Json =
      Map("add-field" -> body.asJson).asJson

    def string(field: Field): AddField =
      AddField(field, "string", true, true, false)

    def textGeneral(field: Field): AddField =
      AddField(field, "text_general", true, true, false)

    def textLang(field: Field, lang: Language): AddField =
      if (lang == Language.Czech) AddField(field, s"text_cz", true, true, false)
      else AddField(field, s"text_${lang.iso2}", true, true, false)
  }

  case class DeleteField(name: Field)
  object DeleteField {
    implicit val encoder: Encoder[DeleteField] =
      deriveEncoder[DeleteField]

    def command(body: DeleteField): Json =
      Map("delete-field" -> body.asJson).asJson
  }
}
