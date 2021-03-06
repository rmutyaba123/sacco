INSERT INTO sys_continents (sys_continent_id, sys_continent_name) VALUES
('AF', 'Africa'),
('AS', 'Asia'),
('EU', 'Europe'),
('NA', 'North America'),
('SA', 'South America'),
('OC', 'Oceania'),
('AN', 'Antarctica');


INSERT INTO public.sys_countrys (sys_country_id, sys_continent_id, sys_country_code, sys_country_name, sys_country_number, sys_country_capital, sys_phone_code, sys_currency_name, sys_currency_code, sys_currency_cents, sys_currency_exchange) VALUES 
('AS', 'OC', 'ASM', 'American Samoa', '016', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('AO', 'AF', 'AGO', 'Angola', '024', NULL, NULL, 'Kwanza', 'AOA', NULL, NULL),
('AI', 'NA', 'AIA', 'Anguilla', '660', NULL, NULL, 'East Carribbean Dollar', 'XCD', NULL, NULL),
('AQ', 'AN', 'ATA', 'Antarctica', '010', NULL, NULL, 'No universal currency', ' ', NULL, NULL),
('AG', 'NA', 'ATG', 'Antigua and Barbuda', '028', NULL, NULL, 'East Carribean Dollar', 'XCD', NULL, NULL),
('AR', 'SA', 'ARG', 'Argentina', '032', NULL, NULL, 'Argentine Peso', 'ARS', NULL, NULL),
('AM', 'AS', 'ARM', 'Armenia', '051', NULL, NULL, 'Armenian Dram', 'AMD', NULL, NULL),
('AW', 'NA', 'ABW', 'Aruba', '533', NULL, NULL, 'Aruban Guilder', 'AWG', NULL, NULL),
('AU', 'OC', 'AUS', 'Australia', '036', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('AT', 'EU', 'AUT', 'Austria', '040', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('AZ', 'AS', 'AZE', 'Azerbaijan', '031', NULL, NULL, 'Azerbaijanian Manat', 'AZM', NULL, NULL),
('BS', 'NA', 'BHS', 'Bahamas', '044', NULL, NULL, 'Bahamian Dollar', 'BSD', NULL, NULL),
('BH', 'AS', 'BHR', 'Bahrain', '048', NULL, NULL, 'Bahraini Dinar', 'BHD', NULL, NULL),
('BD', 'AS', 'BGD', 'Bangladesh', '050', NULL, NULL, 'Taka', 'BDT', NULL, NULL),
('BB', 'NA', 'BRB', 'Barbados', '052', NULL, NULL, 'Barbados Dollar', 'BBD', NULL, NULL),
('BY', 'EU', 'BLR', 'Belarus', '112', NULL, NULL, 'Belarussian Ruble', 'BYR', NULL, NULL),
('BE', 'EU', 'BEL', 'Belgium', '056', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('BZ', 'NA', 'BLZ', 'Belize', '084', NULL, NULL, 'Belize Dollar', 'BZD', NULL, NULL),
('BJ', 'AF', 'BEN', 'Benin', '204', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('BM', 'NA', 'BMU', 'Bermuda', '060', NULL, NULL, 'Bermudian Dollar', 'BMD', NULL, NULL),
('BT', 'AS', 'BTN', 'Bhutan', '064', NULL, NULL, 'Indian Rupee', 'INR', NULL, NULL),
('BO', 'SA', 'BOL', 'Bolivia', '068', NULL, NULL, 'Boliviano', 'BOB', NULL, NULL),
('BA', 'EU', 'BIH', 'Bosnia and Herzegovina', '070', NULL, NULL, 'Convertible Marks', 'BAM', NULL, NULL),
('BW', 'AF', 'BWA', 'Botswana', '072', NULL, NULL, 'Pula', 'BWP', NULL, NULL),
('BV', 'AN', 'BVT', 'Bouvet Island', '074', NULL, NULL, 'Norvegian Krone', 'NOK', NULL, NULL),
('BR', 'SA', 'BRA', 'Brazil', '076', NULL, NULL, 'Brazilian Real', 'BRL', NULL, NULL),
('IO', 'AS', 'IOT', 'British Indian Ocean Territory', '086', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('BN', 'AS', 'BRN', 'Brunei Darussalam', '096', NULL, NULL, 'Brunei Dollar', 'BND', NULL, NULL),
('BG', 'EU', 'BGR', 'Bulgaria', '100', NULL, NULL, 'Bulgarian Lev', 'BGN', NULL, NULL),
('BF', 'AF', 'BFA', 'Burkina Faso', '854', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('BI', 'AF', 'BDI', 'Burundi', '108', NULL, NULL, 'Burundi Franc', 'BIF', NULL, NULL),
('KH', 'AS', 'KHM', 'Cambodia', '116', NULL, NULL, 'Riel', 'KHR', NULL, NULL),
('CM', 'AF', 'CMR', 'Cameroon', '120', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('CA', 'NA', 'CAN', 'Canada', '124', NULL, NULL, 'Canadian Dollar', 'CAD', NULL, NULL),
('CV', 'AF', 'CPV', 'Cape Verde', '132', NULL, NULL, 'Cape Verde Escudo', 'CVE', NULL, NULL),
('KY', 'NA', 'CYM', 'Cayman Islands', '136', NULL, NULL, 'Cayman Islands Dollar', 'KYD', NULL, NULL),
('CF', 'AF', 'CAF', 'Central African Republic', '140', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('TD', 'AF', 'TCD', 'Chad', '148', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('CL', 'SA', 'CHL', 'Chile', '152', NULL, NULL, 'Chilean Peso', 'CLP', NULL, NULL),
('CN', 'AS', 'CHN', 'China', '156', NULL, NULL, 'Yuan Renminbi', 'CNY', NULL, NULL),
('CX', 'AS', 'CXR', 'Christmas Island', '162', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('CC', 'AS', 'CCK', 'Cocos Keeling Islands', '166', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('CO', 'SA', 'COL', 'Colombia', '170', NULL, NULL, 'Colombian Peso', 'COP', NULL, NULL),
('KM', 'AF', 'COM', 'Comoros', '174', NULL, NULL, 'Comoro Franc', 'KMF', NULL, NULL),
('CG', 'AF', 'COG', 'Republic of Congo', '178', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('CD', 'AF', 'COD', 'Democratic Republic of Congo', '180', NULL, NULL, 'Franc Congolais', 'CDF', NULL, NULL),
('CK', 'OC', 'COK', 'Cook Islands', '184', NULL, NULL, 'New Zealand Dollar', 'NZD', NULL, NULL),
('CR', 'NA', 'CRI', 'Costa Rica', '188', NULL, NULL, 'Costa Rican Colon', 'CRC', NULL, NULL),
('CI', 'AF', 'CIV', 'Cote d Ivoire', '384', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('HR', 'EU', 'HRV', 'Croatia', '191', NULL, NULL, 'Croatian kuna', 'HRK', NULL, NULL),
('CU', 'NA', 'CUB', 'Cuba', '192', NULL, NULL, 'Cuban Peso', 'CUP', NULL, NULL),
('CY', 'AS', 'CYP', 'Cyprus', '196', NULL, NULL, 'Cyprus Pound', 'CYP', NULL, NULL),
('CZ', 'EU', 'CZE', 'Czech Republic', '203', NULL, NULL, 'Czech Koruna', 'CZK', NULL, NULL),
('DK', 'EU', 'DNK', 'Denmark', '208', NULL, NULL, 'Danish Krone', 'DKK', NULL, NULL),
('DJ', 'AF', 'DJI', 'Djibouti', '262', NULL, NULL, 'Djibouti Franc', 'DJF', NULL, NULL),
('DM', 'NA', 'DMA', 'Dominica', '212', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('DO', 'NA', 'DOM', 'Dominican Republic', '214', NULL, NULL, 'Dominican Peso', 'DOP', NULL, NULL),
('EC', 'SA', 'ECU', 'Ecuador', '218', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('EG', 'AF', 'EGY', 'Egypt', '818', NULL, NULL, 'Egyptian Pound', 'EGP', NULL, NULL),
('SV', 'NA', 'SLV', 'El Salvador', '222', NULL, NULL, 'El Salvador Colon', 'SVC', NULL, NULL),
('GQ', 'AF', 'GNQ', 'Equatorial Guinea', '226', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('ER', 'AF', 'ERI', 'Eritrea', '232', NULL, NULL, 'Nakfa', 'ERN', NULL, NULL),
('EE', 'EU', 'EST', 'Estonia', '233', NULL, NULL, 'Kroon', 'EEK', NULL, NULL),
('ET', 'AF', 'ETH', 'Ethiopia', '231', NULL, NULL, 'Ethiopian Birr', 'ETB', NULL, NULL),
('FK', 'SA', 'FLK', 'Falkland Islands', '238', NULL, NULL, 'Falkland Islands Pound', 'FKP', NULL, NULL),
('FO', 'EU', 'FRO', 'Faroe Islands', '234', NULL, NULL, 'Danish Krone', 'DKK', NULL, NULL),
('FJ', 'OC', 'FJI', 'Fiji', '242', NULL, NULL, 'Fiji Dollar', 'FJD', NULL, NULL),
('FI', 'EU', 'FIN', 'Finland', '246', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('FR', 'EU', 'FRA', 'France', '250', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GF', 'SA', 'GUF', 'French Guiana', '254', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('PF', 'OC', 'PYF', 'French Polynesia', '258', NULL, NULL, 'CFP Franc', 'XPF', NULL, NULL),
('TF', 'AN', 'ATF', 'French Southern Territories', '260', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GA', 'AF', 'GAB', 'Gabon', '266', NULL, NULL, 'CFA Franc BEAC', 'XAF', NULL, NULL),
('GM', 'AF', 'GMB', 'Gambia', '270', NULL, NULL, 'Dalasi', 'GMD', NULL, NULL),
('GE', 'AS', 'GEO', 'Georgia', '268', NULL, NULL, 'Lari', 'GEL', NULL, NULL),
('DE', 'EU', 'DEU', 'Germany', '276', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GH', 'AF', 'GHA', 'Ghana', '288', NULL, NULL, 'Cedi', 'GHC', NULL, NULL),
('GI', 'EU', 'GIB', 'Gibraltar', '292', NULL, NULL, 'Gibraltar Pound', 'GIP', NULL, NULL),
('GR', 'EU', 'GRC', 'Greece', '300', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GL', 'NA', 'GRL', 'Greenland', '304', NULL, NULL, 'Danish Krone', 'DKK', NULL, NULL),
('GD', 'NA', 'GRD', 'Grenada', '308', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('GP', 'NA', 'GLP', 'Guadeloupe', '312', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GU', 'OC', 'GUM', 'Guam', '316', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('GT', 'NA', 'GTM', 'Guatemala', '320', NULL, NULL, 'Quetzal', 'GTQ', NULL, NULL),
('GN', 'AF', 'GIN', 'Guinea', '324', NULL, NULL, 'Guinea Franc', 'GNF', NULL, NULL),
('GW', 'AF', 'GNB', 'Guinea-Bissau', '624', NULL, NULL, 'Guinea-Bissau Peso', 'GWP', NULL, NULL),
('GY', 'SA', 'GUY', 'Guyana', '328', NULL, NULL, 'Guyana Dollar', 'GYD', NULL, NULL),
('HT', 'NA', 'HTI', 'Haiti', '332', NULL, NULL, 'Gourde', 'HTG', NULL, NULL),
('HM', 'AN', 'HMD', 'Heard Island and McDonald Islands', '334', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('VA', 'EU', 'VAT', 'Vatican City State', '336', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('HN', 'NA', 'HND', 'Honduras', '340', NULL, NULL, 'Lempira', 'HNL', NULL, NULL),
('HK', 'AS', 'HKG', 'Hong Kong', '344', NULL, NULL, 'Hong Kong Dollar', 'HKD', NULL, NULL),
('HU', 'EU', 'HUN', 'Hungary', '348', NULL, NULL, 'Forint', 'HUF', NULL, NULL),
('IS', 'EU', 'ISL', 'Iceland', '352', NULL, NULL, 'Iceland Krona', 'ISK', NULL, NULL),
('IN', 'AS', 'IND', 'India', '356', NULL, NULL, 'Indian Rupee', 'INR', NULL, NULL),
('AF', 'AS', 'AFG', 'Afghanistan', '004', NULL, NULL, 'Afghani', 'AFN', NULL, NULL),
('AL', 'EU', 'ALB', 'Albania', '008', NULL, NULL, 'Lek', 'ALL', NULL, NULL),
('DZ', 'AF', 'DZA', 'Algeria', '012', NULL, NULL, 'Algerian Dinar', 'DZD', NULL, NULL),
('LU', 'EU', 'LUX', 'Luxembourg', '442', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('ID', 'AS', 'IDN', 'Indonesia', '360', NULL, NULL, 'Rupiah', 'IDR', NULL, NULL),
('IR', 'AS', 'IRN', 'Iran', '364', NULL, NULL, 'Iranian Rial', 'IRR', NULL, NULL),
('IQ', 'AS', 'IRQ', 'Iraq', '368', NULL, NULL, 'Iraqi Dinar', 'IQD', NULL, NULL),
('IE', 'EU', 'IRL', 'Ireland', '372', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('IL', 'AS', 'ISR', 'Israel', '376', NULL, NULL, 'New Israeli Sheqel', 'ILS', NULL, NULL),
('IT', 'EU', 'ITA', 'Italy', '380', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('JM', 'NA', 'JAM', 'Jamaica', '388', NULL, NULL, 'Jamaican Dollar', 'JMD', NULL, NULL),
('JP', 'AS', 'JPN', 'Japan', '392', NULL, NULL, 'Yen', 'JPY', NULL, NULL),
('JO', 'AS', 'JOR', 'Jordan', '400', NULL, NULL, 'Jordanian Dinar', 'JOD', NULL, NULL),
('KZ', 'AS', 'KAZ', 'Kazakhstan', '398', NULL, NULL, 'Tenge', 'KZT', NULL, NULL),
('KE', 'AF', 'KEN', 'Kenya', '404', NULL, NULL, 'Kenyan Shilling', 'KES', NULL, NULL),
('KI', 'OC', 'KIR', 'Kiribati', '296', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('KP', 'AS', 'PRK', 'North Korea', '408', NULL, NULL, 'North Korean Won', 'KPW', NULL, NULL),
('KR', 'AS', 'KOR', 'South Korea', '410', NULL, NULL, 'Won', 'KRW', NULL, NULL),
('KW', 'AS', 'KWT', 'Kuwait', '414', NULL, NULL, 'Kuwaiti Dinar', 'KWD', NULL, NULL),
('KG', 'AS', 'KGZ', 'Kyrgyz Republic', '417', NULL, NULL, 'Som', 'KGS', NULL, NULL),
('LA', 'AS', 'LAO', 'Lao Peoples Democratic Republic', '418', NULL, NULL, 'Kip', 'LAK', NULL, NULL),
('LV', 'EU', 'LVA', 'Latvia', '428', NULL, NULL, 'Latvian Lats', 'LVL', NULL, NULL),
('LB', 'AS', 'LBN', 'Lebanon', '422', NULL, NULL, 'Lebanese Pound', 'LBP', NULL, NULL),
('LS', 'AF', 'LSO', 'Lesotho', '426', NULL, NULL, 'Rand', 'ZAR', NULL, NULL),
('LR', 'AF', 'LBR', 'Liberia', '430', NULL, NULL, 'Liberian Dollar', 'LRD', NULL, NULL),
('LY', 'AF', 'LBY', 'Libyan Arab Jamahiriya', '434', NULL, NULL, 'Lybian Dinar', 'LYD', NULL, NULL),
('LI', 'EU', 'LIE', 'Liechtenstein', '438', NULL, NULL, 'Swiss Franc', 'CHF', NULL, NULL),
('LT', 'EU', 'LTU', 'Lithuania', '440', NULL, NULL, 'Lithuanian Litas', 'LTL', NULL, NULL),
('MO', 'AS', 'MAC', 'Macao', '446', NULL, NULL, 'Pataca', 'MOP', NULL, NULL),
('MK', 'EU', 'MKD', 'Macedonia', '807', NULL, NULL, 'Denar', 'MKD', NULL, NULL),
('MG', 'AF', 'MDG', 'Madagascar', '450', NULL, NULL, 'Ariary', 'MGA', NULL, NULL),
('MW', 'AF', 'MWI', 'Malawi', '454', NULL, NULL, 'Kwacha', 'MWK', NULL, NULL),
('MY', 'AS', 'MYS', 'Malaysia', '458', NULL, NULL, 'Malaysian Ringgit', 'MYR', NULL, NULL),
('MV', 'AS', 'MDV', 'Maldives', '462', NULL, NULL, 'Rufiyaa', 'MVR', NULL, NULL),
('ML', 'AF', 'MLI', 'Mali', '466', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('MT', 'EU', 'MLT', 'Malta', '470', NULL, NULL, 'Maltese Lira', 'MTL', NULL, NULL),
('MH', 'OC', 'MHL', 'Marshall Islands', '584', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('MQ', 'NA', 'MTQ', 'Martinique', '474', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('MR', 'AF', 'MRT', 'Mauritania', '478', NULL, NULL, 'Ouguiya', 'MRO', NULL, NULL),
('MU', 'AF', 'MUS', 'Mauritius', '480', NULL, NULL, 'Mauritius Rupee', 'MUR', NULL, NULL),
('YT', 'AF', 'MYT', 'Mayotte', '175', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('MX', 'NA', 'MEX', 'Mexico', '484', NULL, NULL, 'Mexican Peso', 'MXN', NULL, NULL),
('FM', 'OC', 'FSM', 'Micronesia', '583', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('MD', 'EU', 'MDA', 'Moldova', '498', NULL, NULL, 'Moldovan Leu', 'MDL', NULL, NULL),
('MC', 'EU', 'MCO', 'Monaco', '492', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('MN', 'AS', 'MNG', 'Mongolia', '496', NULL, NULL, 'Tugrik', 'MNT', NULL, NULL),
('MS', 'NA', 'MSR', 'Montserrat', '500', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('MA', 'AF', 'MAR', 'Morocco', '504', NULL, NULL, 'Moroccan Dirham', 'MAD', NULL, NULL),
('MZ', 'AF', 'MOZ', 'Mozambique', '508', NULL, NULL, 'Metical', 'MZM', NULL, NULL),
('MM', 'AS', 'MMR', 'Myanmar', '104', NULL, NULL, 'Kyat', 'MMK', NULL, NULL),
('NA', 'AF', 'NAM', 'Namibia', '516', NULL, NULL, 'Rand', 'ZAR', NULL, NULL),
('NR', 'OC', 'NRU', 'Nauru', '520', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('NP', 'AS', 'NPL', 'Nepal', '524', NULL, NULL, 'Nepalese Rupee', 'NPR', NULL, NULL),
('NL', 'EU', 'NLD', 'Netherlands', '528', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('AN', 'NA', 'ANT', 'Netherlands Antilles', '530', NULL, NULL, 'Netherlands Antillan Guilder', 'ANG', NULL, NULL),
('NC', 'OC', 'NCL', 'New Caledonia', '540', NULL, NULL, 'CFP Franc', 'XPF', NULL, NULL),
('NZ', 'OC', 'NZL', 'New Zealand', '554', NULL, NULL, 'New Zealand Dollar', 'NZD', NULL, NULL),
('NI', 'NA', 'NIC', 'Nicaragua', '558', NULL, NULL, 'Cordoba Oro', 'NIO', NULL, NULL),
('NE', 'AF', 'NER', 'Niger', '562', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('NG', 'AF', 'NGA', 'Nigeria', '566', NULL, NULL, 'Naira', 'NGN', NULL, NULL),
('NU', 'OC', 'NIU', 'Niue', '570', NULL, NULL, 'New Zealand Dollar', 'NZD', NULL, NULL),
('NF', 'OC', 'NFK', 'Norfolk Island', '574', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('MP', 'OC', 'MNP', 'Northern Mariana Islands', '580', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('NO', 'EU', 'NOR', 'Norway', '578', NULL, NULL, 'Norwegian Krone', 'NOK', NULL, NULL),
('OM', 'AS', 'OMN', 'Oman', '512', NULL, NULL, 'Rial Omani', 'OMR', NULL, NULL),
('PK', 'AS', 'PAK', 'Pakistan', '586', NULL, NULL, 'Pakistan Rupee', 'PKR', NULL, NULL),
('PW', 'OC', 'PLW', 'Palau', '585', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('PS', 'AS', 'PSE', 'Palestinian Territory', '275', NULL, NULL, ' ', ' ', NULL, NULL),
('PA', 'NA', 'PAN', 'Panama', '591', NULL, NULL, 'Balboa', 'PAB', NULL, NULL),
('PG', 'OC', 'PNG', 'Papua New Guinea', '598', NULL, NULL, 'Kina', 'PGK', NULL, NULL),
('PY', 'SA', 'PRY', 'Paraguay', '600', NULL, NULL, 'Guarani', 'PYG', NULL, NULL),
('PE', 'SA', 'PER', 'Peru', '604', NULL, NULL, 'Nuevo Sol', 'PEN', NULL, NULL),
('PH', 'AS', 'PHL', 'Philippines', '608', NULL, NULL, 'Philippine Peso', 'PHP', NULL, NULL),
('PN', 'OC', 'PCN', 'Pitcairn Islands', '612', NULL, NULL, 'New Zealand Dollar', 'NZD', NULL, NULL),
('PL', 'EU', 'POL', 'Poland', '616', NULL, NULL, 'Zloty', 'PLN', NULL, NULL),
('PT', 'EU', 'PRT', 'Portugal', '620', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('PR', 'NA', 'PRI', 'Puerto Rico', '630', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('QA', 'AS', 'QAT', 'Qatar', '634', NULL, NULL, 'Qatari Rial', 'QAR', NULL, NULL),
('RE', 'AF', 'REU', 'Reunion', '638', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('RO', 'EU', 'ROU', 'Romania', '642', NULL, NULL, 'Leu', 'ROL', NULL, NULL),
('RU', 'EU', 'RUS', 'Russian Federation', '643', NULL, NULL, 'Russian Ruble', 'RUR', NULL, NULL),
('RW', 'AF', 'RWA', 'Rwanda', '646', NULL, NULL, 'Rwanda Franc', 'RWF', NULL, NULL),
('SH', 'AF', 'SHN', 'Saint Helena', '654', NULL, NULL, 'Saint Helena Pound', 'SHP', NULL, NULL),
('KN', 'NA', 'KNA', 'Saint Kitts and Nevis', '659', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('LC', 'NA', 'LCA', 'Saint Lucia', '662', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('PM', 'NA', 'SPM', 'Saint Pierre and Miquelon', '666', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('VC', 'NA', 'VCT', 'Saint Vincent and the Grenadines', '670', NULL, NULL, 'East Caribbean Dollar', 'XCD', NULL, NULL),
('WS', 'OC', 'WSM', 'Samoa', '882', NULL, NULL, 'Tala', 'WST', NULL, NULL),
('SM', 'EU', 'SMR', 'San Marino', '674', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('ST', 'AF', 'STP', 'Sao Tome and Principe', '678', NULL, NULL, 'Dobra', 'STD', NULL, NULL),
('SA', 'AS', 'SAU', 'Saudi Arabia', '682', NULL, NULL, 'Saudi Riyal', 'SAR', NULL, NULL),
('SN', 'AF', 'SEN', 'Senegal', '686', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('ME', 'EU', 'MNE', 'Montenegro', '499', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('RS', 'EU', 'SRB', 'Serbia', '688', NULL, NULL, 'Serbian Dinar', 'CSD', NULL, NULL),
('SC', 'AF', 'SYC', 'Seychelles', '690', NULL, NULL, 'Seychelles Rupee', 'SCR', NULL, NULL),
('SL', 'AF', 'SLE', 'Sierra Leone', '694', NULL, NULL, 'Leone', 'SLL', NULL, NULL),
('AD', 'EU', 'AND', 'Andorra', '020', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('SG', 'AS', 'SGP', 'Singapore', '702', NULL, NULL, 'Singapore Dollar', 'SGD', NULL, NULL),
('SK', 'EU', 'SVK', 'Slovakia', '703', NULL, NULL, 'Slovak Koruna', 'SKK', NULL, NULL),
('SI', 'EU', 'SVN', 'Slovenia', '705', NULL, NULL, 'Tolar', 'SIT', NULL, NULL),
('SB', 'OC', 'SLB', 'Solomon Islands', '090', NULL, NULL, 'Solomon Islands Dollar', 'SBD', NULL, NULL),
('SO', 'AF', 'SOM', 'Somalia', '706', NULL, NULL, 'Somali Shilling', 'SOS', NULL, NULL),
('ZA', 'AF', 'ZAF', 'South Africa', '710', NULL, NULL, 'Rand', 'ZAR', NULL, NULL),
('GS', 'AN', 'SGS', 'South Georgia and the South Sandwich Islands', '239', NULL, NULL, ' ', ' ', NULL, NULL),
('ES', 'EU', 'ESP', 'Spain', '724', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('LK', 'AS', 'LKA', 'Sri Lanka', '144', NULL, NULL, 'Sri Lanka Rupee', 'LKR', NULL, NULL),
('SD', 'AF', 'SDN', 'Sudan', '736', NULL, NULL, 'Sudanese Dinar', 'SDD', NULL, NULL),
('SR', 'SA', 'SUR', 'Suriname', '740', NULL, NULL, 'Suriname Dollar', 'SRD', NULL, NULL),
('SJ', 'EU', 'SJM', 'Svalbard & Jan Mayen Islands', '744', NULL, NULL, 'Norwegian Krone', 'NOK', NULL, NULL),
('SZ', 'AF', 'SWZ', 'Swaziland', '748', NULL, NULL, 'Lilangeni', 'SZL', NULL, NULL),
('SE', 'EU', 'SWE', 'Sweden', '752', NULL, NULL, 'Swedish Krona', 'SEK', NULL, NULL),
('CH', 'EU', 'CHE', 'Switzerland', '756', NULL, NULL, 'Swiss Franc', 'CHF', NULL, NULL),
('SY', 'AS', 'SYR', 'Syrian Arab Republic', '760', NULL, NULL, 'Syrian Pound', 'SYP', NULL, NULL),
('TW', 'AS', 'TWN', 'Taiwan', '158', NULL, NULL, 'New Taiwan Dollar', 'TWD', NULL, NULL),
('TJ', 'AS', 'TJK', 'Tajikistan', '762', NULL, NULL, 'Somoni', 'TJS', NULL, NULL),
('TZ', 'AF', 'TZA', 'Tanzania', '834', NULL, NULL, 'Tanzanian Shilling', 'TZS', NULL, NULL),
('TH', 'AS', 'THA', 'Thailand', '764', NULL, NULL, 'Baht', 'THB', NULL, NULL),
('TL', 'AS', 'TLS', 'Timor-Leste', '626', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('TG', 'AF', 'TGO', 'Togo', '768', NULL, NULL, 'CFA Franc BCEAO', 'XOF', NULL, NULL),
('TK', 'OC', 'TKL', 'Tokelau', '772', NULL, NULL, 'New Zealand Dollar', 'NZD', NULL, NULL),
('TO', 'OC', 'TON', 'Tonga', '776', NULL, NULL, 'Paanga', 'TOP', NULL, NULL),
('TT', 'NA', 'TTO', 'Trinidad and Tobago', '780', NULL, NULL, 'Trinidad and Tobago Dollar', 'TTD', NULL, NULL),
('TN', 'AF', 'TUN', 'Tunisia', '788', NULL, NULL, 'Tunisian Dinar', 'TND', NULL, NULL),
('TR', 'AS', 'TUR', 'Turkey', '792', NULL, NULL, 'Turkish Lira', 'TRL', NULL, NULL),
('TM', 'AS', 'TKM', 'Turkmenistan', '795', NULL, NULL, 'Manat', 'TMM', NULL, NULL),
('TC', 'NA', 'TCA', 'Turks and Caicos Islands', '796', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('TV', 'OC', 'TUV', 'Tuvalu', '798', NULL, NULL, 'Australian Dollar', 'AUD', NULL, NULL),
('UG', 'AF', 'UGA', 'Uganda', '800', NULL, NULL, 'Uganda Shilling', 'UGX', NULL, NULL),
('UA', 'EU', 'UKR', 'Ukraine', '804', NULL, NULL, 'Hryvnia', 'UAH', NULL, NULL),
('AE', 'AS', 'ARE', 'United Arab Emirates', '784', NULL, NULL, 'UAE Dirham', 'AED', NULL, NULL),
('GB', 'EU', 'GBR', 'United Kingdom of Great Britain & Northern Ireland', '826', NULL, NULL, 'Pound Sterling', 'GBP', NULL, NULL),
('US', 'NA', 'USA', 'United States of America', '840', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('UM', 'OC', 'UMI', 'United States Minor Outlying Islands', '581', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('UY', 'SA', 'URY', 'Uruguay', '858', NULL, NULL, 'Peso Uruguayo', 'UYU', NULL, NULL),
('UZ', 'AS', 'UZB', 'Uzbekistan', '860', NULL, NULL, 'Uzbekistan Sum', 'UZS', NULL, NULL),
('VU', 'OC', 'VUT', 'Vanuatu', '548', NULL, NULL, 'Vatu', 'VUV', NULL, NULL),
('VE', 'SA', 'VEN', 'Venezuela', '862', NULL, NULL, 'Bolivar', 'VEB', NULL, NULL),
('VN', 'AS', 'VNM', 'Vietnam', '704', NULL, NULL, 'Dong', 'VND', NULL, NULL),
('VG', 'NA', 'VGB', 'British Virgin Islands', '092', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('VI', 'NA', 'VIR', 'United States Virgin Islands', '850', NULL, NULL, 'US Dollar', 'USD', NULL, NULL),
('WF', 'OC', 'WLF', 'Wallis and Futuna', '876', NULL, NULL, 'CFP Franc', 'XPF', NULL, NULL),
('EH', 'AF', 'ESH', 'Western Sahara', '732', NULL, NULL, 'Moroccan Dirham', 'MAD', NULL, NULL),
('YE', 'AS', 'YEM', 'Yemen', '887', NULL, NULL, 'Yemeni Rial', 'YER', NULL, NULL),
('ZM', 'AF', 'ZMB', 'Zambia', '894', NULL, NULL, 'Kwacha', 'ZMK', NULL, NULL),
('ZW', 'AF', 'ZWE', 'Zimbabwe', '716', NULL, NULL, 'Zimbabwe Dollar', 'ZWD', NULL, NULL),
('SS', 'AF', 'SSN', 'South Sudan', '737', NULL, NULL, 'South Sudanese Pound', 'SSP', NULL, NULL),
('AX', 'EU', 'ALA', 'Aland Islands', '248', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('GG', 'EU', 'GGY', 'Guernsey', '831', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('IM', 'EU', 'IMN', 'Isle of Man', '833', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('JE', 'EU', 'JEY', 'Bailiwick of Jersey', '832', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('BL', 'NA', 'BLM', 'Saint Barthelemy', '652', NULL, NULL, 'Euro', 'EUR', NULL, NULL),
('MF', 'NA', 'MAF', 'Saint Martin', '663', NULL, NULL, 'Euro', 'EUR', NULL, NULL);

INSERT INTO sys_nationalitys (sys_nationality_id, sys_nationality_name)
VALUES ('AF','Afghan'),
('AX','??land Island'),
('AL','Albanian'),
('DZ','Algerian'),
('AS','American Samoan'),
('AD','Andorran'),
('AO','Angolan'),
('AI','Anguillan'),
('AQ','Antarctic'),
('AG','Antiguan/Barbudan'),
('AR','Argentine'),
('AM','Armenian'),
('AW','Aruban'),
('AU','Australian'),
('AT','Austrian'),
('AZ','Azerbaijani, Azeri'),
('BS','Bahamian'),
('BH','Bahraini'),
('BD','Bangladeshi'),
('BB','Barbadian'),
('BY','Belarusian'),
('BE','Belgian'),
('BZ','Belizean'),
('BJ','Beninese/Beninois'),
('BM','Bermudian/Bermudan'),
('BT','Bhutanese'),
('BO','Bolivian'),
('BQ','Bonaire'),
('BA','Bosnian/Herzegovinian'),
('BW','Motswana/Botswanan'),
('BV','Bouvet Island'),
('BR','Brazilian'),
('IO','BIOT'),
('BN','Bruneian'),
('BG','Bulgarian'),
('BF','Burkinab??'),
('BI','Burundian'),
('CV','Cabo Verdean'),
('KH','Cambodian'),
('CM','Cameroonian'),
('CA','Canadian'),
('KY','Caymanian'),
('CF','Central African'),
('TD','Chadian'),
('CL','Chilean'),
('CN','Chinese'),
('CX','Christmas Island'),
('CC','Cocos Island'),
('CO','Colombian'),
('KM','Comoran/Comorian'),
('CG','Congolese'),
('CD','Congolese'),
('CK','Cook Island'),
('CR','Costa Rican'),
('CI','Ivorian'),
('HR','Croatian'),
('CU','Cuban'),
('CW','Cura??aoan'),
('CY','Cypriot'),
('CZ','Czech'),
('DK','Danish'),
('DJ','Djiboutian'),
('DM','Dominican'),
('DO','Dominican'),
('EC','Ecuadorian'),
('EG','Egyptian'),
('SV','Salvadoran'),
('GQ','Equatorial Guinean/Equatoguinean'),
('ER','Eritrean'),
('EE','Estonian'),
('ET','Ethiopian'),
('FK','Falkland Island'),
('FO','Faroese'),
('FJ','Fijian'),
('FI','Finnish'),
('FR','French'),
('GF','French Guianese'),
('PF','French Polynesian'),
('TF','French Southern Territories'),
('GA','Gabonese'),
('GM','Gambian'),
('GE','Georgian'),
('DE','German'),
('GH','Ghanaian'),
('GI','Gibraltar'),
('GR','Greek/Hellenic'),
('GL','Greenlandic'),
('GD','Grenadian'),
('GP','Guadeloupe'),
('GU','Guamanian/Guambat'),
('GT','Guatemalan'),
('GG','Channel Island'),
('GN','Guinean'),
('GW','Bissau-Guinean'),
('GY','Guyanese'),
('HT','Haitian'),
('HM','Heard Island/McDonald Islands'),
('VA','Vatican'),
('HN','Honduran'),
('HK','Hong Kong/ Hong Kongese'),
('HU','Hungarian/Magyar'),
('IS','Icelandic'),
('IN','Indian'),
('ID','Indonesian'),
('IR','Iranian/Persian'),
('IQ','Iraqi'),
('IE','Irish'),
('IM','Manx'),
('IL','Israeli'),
('IT','Italian'),
('JM','Jamaican'),
('JP','Japanese'),
('JE','Channel Island'),
('JO','Jordanian'),
('KZ','Kazakhstani/ Kazakh'),
('KE','Kenyan'),
('KI','I-Kiribati'),
('KP','North Korean'),
('KR','South Korean'),
('KW','Kuwaiti'),
('KG','Kyrgyzstani/Kyrgyz/Kirgiz/Kirghiz'),
('LA','Lao, Laotian'),
('LV','Latvian'),
('LB','Lebanese'),
('LS','Basotho'),
('LR','Liberian'),
('LY','Libyan'),
('LI','Liechtenstein'),
('LT','Lithuanian'),
('LU','Luxembourg/Luxembourgish'),
('MO','Macanese, Chinese'),
('MK','Macedonian'),
('MG','Malagasy'),
('MW','Malawian'),
('MY','Malaysian'),
('MV','Maldivian'),
('ML','Malian/Malinese'),
('MT','Maltese'),
('MH','Marshallese'),
('MQ','Martiniquais/Martinican'),
('MR','Mauritanian'),
('MU','Mauritian'),
('YT','Mahoran'),
('MX','Mexican'),
('FM','Micronesian'),
('MD','Moldovan'),
('MC','Mon??gasque/Monacan'),
('MN','Mongolian'),
('ME','Montenegrin'),
('MS','Montserratian'),
('MA','Moroccan'),
('MZ','Mozambican'),
('MM','Burmese'),
('NA','Namibian'),
('NR','Nauruan'),
('NP','Nepali/Nepalese'),
('NL','Dutch/Netherlandic'),
('NC','New Caledonian'),
('NZ','New Zealand, NZ'),
('NI','Nicaraguan'),
('NE','Nigerien'),
('NG','Nigerian'),
('NU','Niuean'),
('NF','Norfolk Island'),
('MP','Northern Marianan'),
('NO','Norwegian'),
('OM','Omani'),
('PK','Pakistani'),
('PW','Palauan'),
('PS','Palestinian'),
('PA','Panamanian'),
('PG','Papua New Guinean, Papuan'),
('PY','Paraguayan'),
('PE','Peruvian'),
('PH','Philippine/Filipino'),
('PN','Pitcairn Island'),
('PL','Polish'),
('PT','Portuguese'),
('PR','Puerto Rican'),
('QA','Qatari'),
('RE','R??unionese/R??unionnais'),
('RO','Romanian'),
('RU','Russian'),
('RW','Rwandan'),
('BL','Barth??lemois'),
('SH','Saint Helenian'),
('KN','Kittitian/Nevisian'),
('LC','Saint Lucian'),
('MF','Saint-Martinoise'),
('PM','Saint-Pierrais/ Miquelonnais'),
('VC','Saint Vincentian/Vincentian'),
('WS','Samoan'),
('SM','Sammarinese'),
('ST','S??o Tom??an'),
('SA','Saudi/Saudi Arabian'),
('SN','Senegalese'),
('RS','Serbian'),
('SC','Seychellois'),
('SL','Sierra Leonean'),
('SG','Singaporean'),
('SX','Sint Maarten'),
('SK','Slovak'),
('SI','Slovenian/Slovene'),
('SB','Solomon Island'),
('SO','Somali/Somalian'),
('ZA','South African'),
('GS','South Georgia/South Sandwich Islands'),
('SS','South Sudanese'),
('ES','Spanish'),
('LK','Sri Lankan'),
('SD','Sudanese'),
('SR','Surinamese'),
('SJ','Svalbard'),
('SZ','Swazi'),
('SE','Swedish'),
('CH','Swiss'),
('SY','Syrian'),
('TW','Chinese/Taiwanese'),
('TJ','Tajikistani'),
('TZ','Tanzanian'),
('TH','Thai'),
('TL','Timorese'),
('TG','Togolese'),
('TK','Tokelauan'),
('TO','Tongan'),
('TT','Trinidadian/Tobagonian'),
('TN','Tunisian'),
('TR','Turkish'),
('TM','Turkmen'),
('TC','Turks and Caicos Island'),
('TV','Tuvaluan'),
('UG','Ugandan'),
('UA','Ukrainian'),
('AE','Emirati/Emirian/Emiri'),
('GB','British, UK'),
('UM','American'),
('US','American'),
('UY','Uruguayan'),
('UZ','Uzbekistani/Uzbek'),
('VU','Ni-Vanuatu/Vanuatuan'),
('VE','Venezuelan'),
('VN','Vietnamese'),
('VG','British Virgin Island'),
('VI','U.S. Virgin Island'),
('WF',' Wallisian'),
('EH','Sahrawi/Sahrawian/Sahraouian'),
('YE','Yemeni'),
('ZM','Zambian'),
('ZW','Zimbabwean');

