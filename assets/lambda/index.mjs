console.log('Loading firehose record transform function');

export const handler = async (event, context, callback) => {
  let success = 0; // Number of valid entries found
  let failure = 0; // Number of invalid entries found

  let records = event.records;
  // Initialize a variable to store the CSV header
  let header = '';
  // Using comma as delimeter
  const delimeter = ',';

  /* Process the list of records and transform them */
  const output = records.map((record) => {
    try {
      // Kinesis data is base64 encoded so decode here
      const payload = Buffer.from(record.data, 'base64').toString('utf-8');
      const jsonData = JSON.parse(payload);
      let row = '';
      // If header is not yet defined, set it based on the keys of the first record
      if (!header) {
        header = Object.keys(jsonData).join(',');
        row = header + "\n" + Object.values(jsonData).map(_ => JSON.stringify(_)).join(delimeter) + "\n";
      } else {
        row = Object.values(jsonData).map(_ => JSON.stringify(_)).join(delimeter) + "\n";
      }
      success++;
      return {
        recordId: record.recordId,
        result: 'Ok',
        data: (Buffer.from(row, 'utf8')).toString('base64'),
      };
    } catch (error) {
      console.error(error);
      /* Failed event, notify the error and leave the record intact */
      failure++;
      return {
        recordId: record.recordId,
        result: 'ProcessingFailed',
        data: record.data,
      };
    }
  });

  console.log(`Processing completed.  Successful records ${success}, Failed records ${failure}.`);

  callback(null, { records: output });
};
