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

/** Compile the original AIR exit fixture without reading game content. */
public class BuildNativeExitProbe {
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
        // Original empty AS3 movie: one frame, no artwork, audio or imported code.
        byte[] empty = HexFormat.of().parseHex(
            "465753121f0000007800055f00000fa000003c010044110800000040000000");
        SWF swf = new SWF(new ByteArrayInputStream(empty), false);
        DoABC2Tag tag = new DoABC2Tag(swf);
        tag.flags = 1;
        tag.name = "original-native-exit-probe";
        swf.addTag(1, tag);
        ABC abc = tag.getABC();
        swf.resetAbcIndex();
        AbcIndexing index = swf.getAbcIndex();
        index.selectAbc(abc);
        new ActionScript3Parser(index).addScript(
            Files.readString(source.resolve("NativeExitProbe.as")),
            "NativeExitProbe.as", 0, 0, "NativeExitProbe", abc);
        tag.setModified(true);
        SymbolClassTag symbol = new SymbolClassTag(swf);
        symbol.tags.add(0);
        symbol.names.add("NativeExitProbe");
        swf.addTag(2, symbol);
        try (OutputStream stream = Files.newOutputStream(output, StandardOpenOption.CREATE_NEW)) {
            swf.saveTo(stream);
        }
        byte[] bytes = Files.readAllBytes(output);
        System.out.println("bytes=" + bytes.length);
        System.out.println("sha256=" + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)));
        System.out.println("output=" + output);
    }
}
