import java.io.ByteArrayInputStream;
import java.io.OutputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.util.HexFormat;
import com.jpexs.decompiler.flash.SWF;
import com.jpexs.decompiler.flash.abc.ABC;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.AbcIndexing;
import com.jpexs.decompiler.flash.abc.avm2.parser.script.ActionScript3Parser;
import com.jpexs.decompiler.flash.configuration.Configuration;
import com.jpexs.decompiler.flash.tags.DoABC2Tag;
import com.jpexs.decompiler.flash.tags.SymbolClassTag;

/** Compile an original Stage3D probe. No game data or existing movie is read. */
public class BuildBatchingProbe {
    public static void main(String[] args) throws Exception {
        if (args.length != 3) {
            throw new IllegalArgumentException("source-directory new-output.swf playerglobal.swc");
        }
        Path source = Path.of(args[0]).toAbsolutePath().normalize();
        Path output = Path.of(args[1]).toAbsolutePath().normalize();
        Path protectedRoot = source;
        for (Path ancestor = source; ancestor != null; ancestor = ancestor.getParent()) {
            if (Files.exists(ancestor.resolve(".git"))) {
                protectedRoot = ancestor;
                break;
            }
        }
        if (output.startsWith(protectedRoot)) {
            throw new IllegalArgumentException("Keep generated movies outside the source checkout/package");
        }
        Configuration.playerLibLocation.set(Path.of(args[2]).toAbsolutePath().toString());
        SWF.initPlayer();
        // Original FWS v18 header, 550x400, 60 fps, one frame, AS3 attribute,
        // ShowFrame and End. No timeline artwork, audio, code or imported assets.
        byte[] empty = HexFormat.of().parseHex(
            "465753121f0000007800055f00000fa000003c010044110800000040000000");
        SWF swf = new SWF(new ByteArrayInputStream(empty), false);
        DoABC2Tag tag = new DoABC2Tag(swf);
        tag.flags = 1;
        tag.name = "original-stage3d-batching-probe";
        swf.addTag(1, tag);
        ABC abc = tag.getABC();
        swf.resetAbcIndex();
        AbcIndexing index = swf.getAbcIndex();
        index.selectAbc(abc);
        String sourceText = Files.readString(source.resolve("BatchingProbe.as"));
        new ActionScript3Parser(index).addScript(
            sourceText, "BatchingProbe.as", 0, 0, "BatchingProbe", abc);
        tag.setModified(true);
        SymbolClassTag symbol = new SymbolClassTag(swf);
        symbol.tags.add(0);
        symbol.names.add("BatchingProbe");
        swf.addTag(2, symbol);
        try (OutputStream stream = Files.newOutputStream(output, StandardOpenOption.CREATE_NEW)) {
            swf.saveTo(stream);
        }
        byte[] bytes = Files.readAllBytes(output);
        String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        System.out.println("bytes=" + bytes.length);
        System.out.println("sha256=" + hash);
        System.out.println("output=" + output);
    }
}
