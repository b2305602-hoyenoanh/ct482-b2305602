import java.io.IOException;
import java.util.StringTokenizer;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.conf.Configured;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Partitioner;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;
import org.apache.hadoop.util.Tool;
import org.apache.hadoop.util.ToolRunner;

/**
 * WordCount cho Buổi 2.
 *   -D wordcount.combiner=true     : bật Combiner (dùng lại IntSumReducer)
 *   -D wordcount.partitioner=true  : dùng FirstLetterPartitioner thay cho HashPartitioner
 *   -D mapreduce.job.reduces=N     : số reduce task
 */
public class WordCount extends Configured implements Tool {

    public static class TokenizerMapper
            extends Mapper<Object, Text, Text, IntWritable> {
        private static final IntWritable ONE = new IntWritable(1);
        private final Text word = new Text();

        @Override
        public void map(Object key, Text value, Context context)
                throws IOException, InterruptedException {
            StringTokenizer itr = new StringTokenizer(value.toString());
            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken());
                context.write(word, ONE);
            }
        }
    }

    public static class IntSumReducer
            extends Reducer<Text, IntWritable, Text, IntWritable> {
        private final IntWritable result = new IntWritable();

        @Override
        public void reduce(Text key, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values) {
                sum += val.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }
    /** Từ bắt đầu bằng chữ in hoa (tên khu vực: HCM, Hanoi, ...) -> reducer 0,
     *  các từ còn lại (danh mục: dien_tu, sach, ...) -> reducer 1 (nếu có >= 2 reducer). */
    public static class FirstLetterPartitioner extends Partitioner<Text, IntWritable> {
        @Override
        public int getPartition(Text key, IntWritable value, int numPartitions) {
            if (numPartitions < 2) {
                return 0;
            }
            char c = key.toString().isEmpty() ? 'a' : key.toString().charAt(0);
            return Character.isUpperCase(c) ? 0 : 1;
        }
    }

    @Override
    public int run(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("Cach dung: hadoop jar wordcount.jar WordCount [-D ...] <input> <output>");
            return 2;
        }
        Configuration conf = getConf();
        Job job = Job.getInstance(conf, "word count");
        job.setJarByClass(WordCount.class);
        job.setMapperClass(TokenizerMapper.class);
        if (conf.getBoolean("wordcount.combiner", false)) {
            job.setCombinerClass(IntSumReducer.class);   // Combiner = Reducer (phép cộng có tính kết hợp)
        }
        if (conf.getBoolean("wordcount.partitioner", false)) {
            job.setPartitionerClass(FirstLetterPartitioner.class);
        }
        job.setReducerClass(IntSumReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        return job.waitForCompletion(true) ? 0 : 1;
    }

    public static void main(String[] args) throws Exception {
        System.exit(ToolRunner.run(new Configuration(), new WordCount(), args));
    }
}
