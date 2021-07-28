INSERT INTO disability (disability_id, disability_name) VALUES (0, 'None');
INSERT INTO disability (disability_id, disability_name) VALUES (1, 'Blind');
INSERT INTO disability (disability_id, disability_name) VALUES (2, 'Deaf');
SELECT setval('disability_disability_id_seq', 3);

INSERT INTO id_types (id_type_id, id_type_name) VALUES (1, 'National ID');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (2, 'Passport');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (3, 'PIN Number');
INSERT INTO id_types (id_type_id, id_type_name) VALUES (4, 'Company Certificate');
SELECT setval('id_types_id_type_id_seq', 2);

INSERT INTO division_types (division_type_id, division_type_name) VALUES (1, 'Crimal');
INSERT INTO division_types (division_type_id, division_type_name) VALUES (2, 'Civil');
INSERT INTO division_types (division_type_id, division_type_name) VALUES (3, 'Family');
INSERT INTO division_types (division_type_id, division_type_name) VALUES (4, 'Constitutional');
INSERT INTO division_types (division_type_id, division_type_name) VALUES (5, 'Land and Environment');
INSERT INTO division_types (division_type_id, division_type_name) VALUES (7, 'Election Disputes');
SELECT setval('division_types_division_type_id_seq', 8);

INSERT INTO rankings (ranking_id, ranking_name) VALUES (1, 'Chief Justice');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (2, 'Supreme Court Judge');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (3, 'Court of Appeal Judge');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (4, 'High Court Judge');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (5, 'Chief Magistrate');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (6, 'Senior Principal Magistrate');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (7, 'Principal Magistrate');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (8, 'Senior Resident Magistrate');
INSERT INTO rankings (ranking_id, ranking_name) VALUES (9, 'Resident Magistrate');
SELECT setval('rankings_ranking_id_seq', 10);

INSERT INTO court_ranks (court_rank_id, court_rank_name) VALUES (1, 'Supreme Court');
INSERT INTO court_ranks (court_rank_id, court_rank_name) VALUES (2, 'Court of Appeal');
INSERT INTO court_ranks (court_rank_id, court_rank_name) VALUES (3, 'High Court');
INSERT INTO court_ranks (court_rank_id, court_rank_name) VALUES (4, 'Constitutional Court');
INSERT INTO court_ranks (court_rank_id, court_rank_name) VALUES (5, 'Magistrate Court');
SELECT setval('court_ranks_court_rank_id_seq', 6);

INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (1, 'Commercial');
INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (2, 'Family');
INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (3, 'Insurance');
INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (4, 'Constitution');
INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (5, 'Contract');
INSERT INTO case_subjects (case_subject_id, case_subject_name, ep) VALUES (6, 'Electoral Disputes', true);
INSERT INTO case_subjects (case_subject_id, case_subject_name) VALUES (7, 'Criminal');
SELECT setval('case_subjects_case_subject_id_seq', 8);

INSERT INTO judgment_status (judgment_status_id, judgment_status_name) VALUES (1, 'Active');
INSERT INTO judgment_status (judgment_status_id, judgment_status_name) VALUES (2, 'Dormant');
INSERT INTO judgment_status (judgment_status_id, judgment_status_name) VALUES (3, 'Satisfied');
INSERT INTO judgment_status (judgment_status_id, judgment_status_name) VALUES (4, 'Partially satisfied');
INSERT INTO judgment_status (judgment_status_id, judgment_status_name) VALUES (5, 'Expired');
SELECT setval('judgment_status_judgment_status_id_seq', 6);

INSERT INTO case_types (case_type_id, case_type_name) VALUES (1, 'Crimal Cases');
INSERT INTO case_types (case_type_id, case_type_name) VALUES (2, 'Civil Cases');
INSERT INTO case_types (case_type_id, case_type_name) VALUES (3, 'Crimal Appeal');
INSERT INTO case_types (case_type_id, case_type_name) VALUES (4, 'Civil Appeal');
INSERT INTO case_types (case_type_id, case_type_name) VALUES (5, 'Election Disputes');
INSERT INTO case_types (case_type_id, case_type_name) VALUES (7, 'Civil Applications');
SELECT setval('case_types_case_type_id_seq', 7);

INSERT INTO Case_Category (case_type_id, Case_Category_title, Case_Category_name) VALUES ('3', 'Criminal Appleal', 'Criminal Appleal');

INSERT INTO Case_Category (case_type_id, Case_Category_title, Case_Category_name) VALUES ('4', 'Civil Appleal', 'Civil Appleal');
INSERT INTO Case_Category (case_type_id, Case_Category_title, Case_Category_name) VALUES ('7', 'Clvil Applications', 'Civil Applications');

INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.01', 'Murder, Manslaughter and Infanticide', 'Murder');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.02', 'Murder, Manslaughter and Infanticide', 'Manslaughter');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.03', 'Murder, Manslaughter and Infanticide', 'Manslaughter (Fatal Accident)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.04', 'Murder, Manslaughter and Infanticide', 'Suspicious  Death');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.05', 'Murder, Manslaughter and Infanticide', 'Attempted Murder');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '1.06', 'Murder, Manslaughter and Infanticide', 'Infanticide');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.01', 'Other Serious Violent Offences', 'Abduction');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.02', 'Other Serious Violent Offences', 'Act intending to cause GBH');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.03', 'Other Serious Violent Offences', 'Assault on a Police Officer');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.04', 'Other Serious Violent Offences', 'Assaulting a child');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.05', 'Other Serious Violent Offences', 'Grievous Harm');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.06', 'Other Serious Violent Offences', 'Grievous Harm (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.07', 'Other Serious Violent Offences', 'Kidnapping');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.08', 'Other Serious Violent Offences', 'Physical abuse');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.09', 'Other Serious Violent Offences', 'Wounding');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '2.10', 'Other Serious Violent Offences', 'Wounding (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '3.01', 'Robberies', 'Attempted robbery');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '3.02', 'Robberies', 'Robbery with violence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '3.03', 'Robberies', 'Robbery of mobile phone');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.01', 'Sexual offences', 'Attempted rape');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.02', 'Sexual offences', 'Rape');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.03', 'Sexual offences', 'Child abuse');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.04', 'Sexual offences', 'Indecent assault');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.05', 'Sexual offences', 'Sexual Abuse');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.06', 'Sexual offences', 'Sexual assault');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '4.07', 'Sexual offences', 'Sexual interference with a child');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.01', 'Other Offences Against the Person', 'A.O.A.B.H');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.02', 'Other Offences Against the Person', 'A.O.A.B.H (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.03', 'Other Offences Against the Person', 'Assaulting a child');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.04', 'Other Offences Against the Person', 'Assaulting a child (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.05', 'Other Offences Against the Person', 'Child neglect');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.06', 'Other Offences Against the Person', 'Common Assault');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.07', 'Other Offences Against the Person', 'Common Assault (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.08', 'Other Offences Against the Person', 'Indecent act');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.09', 'Other Offences Against the Person', 'Obstruction of a Police Officer');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.10', 'Other Offences Against the Person', 'Procuring Abortion');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.11', 'Other Offences Against the Person', 'Resisting arrest');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.12', 'Other Offences Against the Person', 'Seditious offences');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.13', 'Other Offences Against the Person', 'Threatening Violence (D.V)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '5.14', 'Other Offences Against the Person', 'Threatening Violence ');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.01', 'Property Offences', 'Attempted breaking');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.02', 'Property Offences', 'Attempted burglary');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.03', 'Property Offences', 'Breaking into a building other than a dwelling');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.04', 'Property Offences', 'Breaking into a building other than a dwelling and stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.05', 'Property Offences', 'Breaking into a building with intent to commit a felony');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.06', 'Property Offences', 'Burglary');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.07', 'Property Offences', 'Burglary and stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.08', 'Property Offences', 'Entering a dwelling house ');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.09', 'Property Offences', 'Entering a dwelling house and stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.10', 'Property Offences', 'Entering a dwelling house with intent to commit a felony');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.11', 'Property Offences', 'Entering a building with intent to commit a felony');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.12', 'Property Offences', 'House breaking ');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.13', 'Property Offences', 'House breaking and stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.14', 'Property Offences', 'House breaking with intent to commit a felony');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.15', 'Property Offences', 'Stealing by servant');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.16', 'Property Offences', 'Stealing from vehicle');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.17', 'Property Offences', 'Stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.18', 'Property Offences', 'Unlawful use of a vehicle');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.19', 'Property Offences', 'Unlawful possession of property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '6.20', 'Property Offences', 'Unlawful use of boat or vessel');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.01', 'Theft', 'Attempted stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.02', 'Theft', 'Beach theft');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.03', 'Theft', 'Receiving stolen property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.04', 'Theft', 'Retaining Stolen Property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.05', 'Theft', 'Stealing');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.06', 'Theft', 'Stealing by finding');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.07', 'Theft', 'Stealing by servant');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.08', 'Theft', 'Stealing from boat or vessel');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.09', 'Theft', 'Stealing from dwelling house');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.10', 'Theft', 'Stealing from hotel room');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.11', 'Theft', 'Stealing from person');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.12', 'Theft', 'Stealing from vehicle');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.13', 'Theft', 'Unlawful possession of property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.14', 'Theft', 'Unlawful use of a vehicle');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '7.15', 'Theft', 'Unlawful use of boat or vessel');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '8.01', 'Arson and criminal damage', 'Arson');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '8.02', 'Arson and criminal damage', 'Attempted Arson');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '8.03', 'Arson and criminal damage', 'Criminal trespass');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '8.04', 'Arson and criminal damage', 'Damaging government property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '8.05', 'Arson and criminal damage', 'Damaging property');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.01', 'Fraud', 'Bribery');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.02', 'Fraud', 'Extortion ');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.03', 'Fraud', 'False accounting');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.04', 'Fraud', 'Forgery');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.05', 'Fraud', 'Fraud');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.06', 'Fraud', 'Giving false information to Govt employee');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.07', 'Fraud', 'Importing or purchasing forged notes');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.08', 'Fraud', 'Issuing a cheque without provision');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.09', 'Fraud', 'Misappropriation of money');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.10', 'Fraud', 'Money laundering');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.11', 'Fraud', 'Obtaining credit by false pretence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.12', 'Fraud', 'Obtaining fares by false pretence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.13', 'Fraud', 'Obtaining goods by false pretence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.14', 'Fraud', 'Obtaining money by false pretence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.15', 'Fraud', 'Obtaining service by false pretence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.16', 'Fraud', 'Offering a bribe to Govt employee');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.17', 'Fraud', 'Perjury');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.18', 'Fraud', 'Possession of false/counterfeit currency');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.19', 'Fraud', 'Possession of false document');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.20', 'Fraud', 'Trading as a contractor without a licence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.21', 'Fraud', 'Trading without a licence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.22', 'Fraud', 'Unlawful possession of forged notes');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '9.23', 'Fraud', 'Uttering false notes');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.01', 'Public Order Offences', 'Affray');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.02', 'Public Order Offences', 'Attempt to commit negligent act to cause harm');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.03', 'Public Order Offences', 'Burning rubbish without permit');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.04', 'Public Order Offences', 'Common Nuisance');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.05', 'Public Order Offences', 'Consuming alcohol in a public place');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.06', 'Public Order Offences', 'Cruelty to animals');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.07', 'Public Order Offences', 'Defamation of the President');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.08', 'Public Order Offences', 'Disorderly conduct in a Police building');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.09', 'Public Order Offences', 'Entering a restricted airport attempting to board');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.10', 'Public Order Offences', 'Idle and disorderly (A-i)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.11', 'Public Order Offences', 'Insulting the modesty of a woman');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.12', 'Public Order Offences', 'Loitering');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.13', 'Public Order Offences', 'Negligent act');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.14', 'Public Order Offences', 'Rash and negligent act');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.15', 'Public Order Offences', 'Reckless or negligent act');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.16', 'Public Order Offences', 'Rogue and vagabond');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.17', 'Public Order Offences', 'Unlawful assembly');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.18', 'Public Order Offences', 'Throwing litter in a public place');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '10.19', 'Public Order Offences', 'Using obscene and indescent language in public place');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.01', 'Offences relating to the administration of justice', 'Aiding and abetting escape prisoner');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.02', 'Offences relating to the administration of justice', 'Attempted escape');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.03', 'Offences relating to the administration of justice', 'Breach of court order');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.04', 'Offences relating to the administration of justice', 'Contempt of court');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.05', 'Offences relating to the administration of justice', 'Escape from lawful custody');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.06', 'Offences relating to the administration of justice', 'Failing to comply with bail');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.07', 'Offences relating to the administration of justice', 'Refuse to give name');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '11.08', 'Offences relating to the administration of justice', 'Trafficking in hard drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.01', 'Drugs', 'Cultivation of controlled drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.02', 'Drugs', 'Importation of controlled drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.03', 'Drugs', 'Possession of controlled drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.04', 'Drugs', 'Possession of hard drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.05', 'Drugs', 'Poss of syringe for consumption or administration of controlled drugs.');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.06', 'Drugs', 'Presumption of Consumption Of Controlled Drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.07', 'Drugs', 'Refuse to give control samples');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.08', 'Drugs', 'Trafficking controlled drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '12.09', 'Drugs', 'Trafficking in hard drugs');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '13.01', 'Weapons and Ammunition', 'Importation of firearm and ammunition');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '13.02', 'Weapons and Ammunition', 'Possession of explosive(includes Tuna Crackers)');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '13.03', 'Weapons and Ammunition', 'Possession of offensive weapon');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '13.04', 'Weapons and Ammunition', 'Possession of spear gun');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '13.05', 'Weapons and Ammunition', 'Unlawful possession of a firearm');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.01', 'Environment and Fisheries', 'Catching turtle');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.02', 'Environment and Fisheries', 'Cutting or selling protected trees without a permit');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.03', 'Environment and Fisheries', 'Cutting protected trees without a permit');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.04', 'Environment and Fisheries', 'Dealing in nature nuts');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.05', 'Environment and Fisheries', 'Illegal fishing in Seychelles territoiral waters');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.06', 'Environment and Fisheries', 'Possession of Coco De Mer without a permit');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.07', 'Environment and Fisheries', 'Removal of sand without permit');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.08', 'Environment and Fisheries', 'Selling Protected trees');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.09', 'Environment and Fisheries', 'Stealing protected animals');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.10', 'Environment and Fisheries', 'Taking or processing of sea cucumber without a licence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.11', 'Environment and Fisheries', 'Unauthorised catching of sea cucumber in Seychelles');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '14.12', 'Environment and Fisheries', 'Unlawful possession of a turtle meat, turtle shell, dolphin and lobster');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.01', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Piracy');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.02', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Allowing animals to stray');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.03', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Bigamy');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.04', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Endangering the safety of an aircraft');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.05', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Gamble');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.06', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Illegal connection of water');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.07', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Killing of an animal with intent to steal');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.08', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Possesion of more than 20 litres of baka or lapire without licence');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.09', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Possession of pornographic materials');
INSERT INTO Case_Category (case_type_id, Case_Category_no, Case_Category_title, Case_Category_name) VALUES ('1', '15.10', 'Other crimes Not Elsewhere Classified (Miscellaneous)', 'Prohibited goods');

INSERT INTO Case_Category (case_type_id, Case_Category_name) VALUES ('2', 'Divorce');
INSERT INTO Case_Category (case_type_id, Case_Category_name) VALUES ('2', 'Civil Ex-Parte');
INSERT INTO Case_Category (case_type_id, Case_Category_name) VALUES ('2', 'Civil Suit');
INSERT INTO Case_Category (case_type_id, Case_Category_name) VALUES ('2', 'Petition/Application');
INSERT INTO Case_Category (case_type_id, Case_Category_name) VALUES ('2', 'Miscellaneous Application');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name) VALUES (400, '2', 'Insurance Claim');

INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (411, '5', 'Presidental', 'PR');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (412, '5', 'Senator', 'SE');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (413, '5', 'Governor', 'GO');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (414, '5', 'Women Representative', 'WR');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (415, '5', 'Parliamentary', 'MP');
INSERT INTO Case_Category (Case_Category_id, case_type_id, Case_Category_name, special_suffix) VALUES (416, '5', 'County Representative', 'CR');
SELECT setval('case_category_case_category_id_seq', 1001);

INSERT INTO activitys (activity_id, activity_name, ep) VALUES ('1', 'Hearing', true);
INSERT INTO activitys (activity_id, activity_name) VALUES ('2', 'Application');
INSERT INTO activitys (activity_id, activity_name) VALUES ('3', 'Interlocutory Application');
INSERT INTO activitys (activity_id, activity_name) VALUES ('4', 'Filing a Suite');
INSERT INTO activitys (activity_id, activity_name) VALUES ('5', 'Filing an appleal');
INSERT INTO activitys (activity_id, activity_name, ep) VALUES ('6', 'Ruling', true);
INSERT INTO activitys (activity_id, activity_name, ep) VALUES ('7', 'Judgement', true);
INSERT INTO activitys (activity_id, activity_name) VALUES ('8', 'Taking of Plea');
INSERT INTO activitys (activity_id, activity_name) VALUES ('9', 'Bail Pending Trial');
INSERT INTO activitys (activity_id, activity_name) VALUES ('10', 'Examination-in-Chief');
INSERT INTO activitys (activity_id, activity_name) VALUES ('11', 'Cross-Examination');
INSERT INTO activitys (activity_id, activity_name) VALUES ('12', 'Re-Examination');
INSERT INTO activitys (activity_id, activity_name) VALUES ('13', 'Defence Hearing');
INSERT INTO activitys (activity_id, activity_name) VALUES ('14', 'Sentencing');

INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('21', 'Filing an election petition', true, false);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('22', 'Return of service', true, false);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('23', 'Response to petition', true, false);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('24', 'Consolidation of election petitions', true, false);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('25', 'Pre-trial conferencing', true, true);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('26', 'Transfer Case', true, false);
INSERT INTO activitys (activity_id, activity_name, ep, show_on_diary) VALUES ('27', 'Withdraw election petition', true, false);
SELECT setval('activitys_activity_id_seq', 30);

INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (0, 'Not Heard');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (1, 'Order');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (2, 'Ruling');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (3, 'Judgement');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (4, 'Adjourned');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (5, 'Adjourned Sine Die');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (6, 'Closed Withdrawn');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (7, 'Consent Order filed');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (8, 'Ruling reserved');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (9, 'Change of Judge');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (10, 'Grant Appleal');

INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (11, 'Petition Filled');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (12, 'Service returned');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (14, 'Responded to petition');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (15, 'Heard');
INSERT INTO activity_results (activity_result_id, activity_result_name) VALUES (16, 'Petition Withdrawn');
SELECT setval('activity_results_activity_result_id_seq', 16);

INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (0, 'Not Adjourned');
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (1, 'Undetermined');
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (2, 'Party Absent');
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (3, 'Attorney Absent'); 
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (4, 'Witness Absent');
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (5, 'Interpretor Absent'); 
INSERT INTO adjorn_reasons (adjorn_reason_id, adjorn_reason_name) VALUES (6, 'Other reasons');
SELECT setval('adjorn_reasons_adjorn_reason_id_seq', 7);

INSERT INTO contact_types (contact_type_id, contact_type_name, bench, ep) VALUES (1, 'Presiding Judge', true, true);
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (2, 'Prosecutor');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (3, 'Prosecution Witness');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (4, 'Accused');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (5, 'Plaintiff');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (6, 'Defendant');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (7, 'Appellant');
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (8, 'Respondent', true);
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (9, 'Applicant');
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (10, 'Petitioner', true); 
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (11, 'Advocate of the Plaintiff');
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (12, 'Advocate of the Defendant');
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (13, 'Advocate of the Petitioner', true);
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (14, 'Advocate of the Respondent', true);
INSERT INTO contact_types (contact_type_id, contact_type_name) VALUES (15, 'Defence Witness');
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (16, 'Petitioner Witness', true);
INSERT INTO contact_types (contact_type_id, contact_type_name, ep) VALUES (17, 'Respondent Witness', true);
SELECT setval('contact_types_contact_type_id_seq', 18);

INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 21, 10, 1, 5, 7, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 22, 8, 2, 25, 28, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 23, 8, 3, 25, 28, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 24, null, 4, 32, 35, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 25, null, 5, 39, 42, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 26, null, 6, 47, 49, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 1, null, 7, 55, 60, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (411, 7, null, 8, 65, 70, true);


INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 21, 10, 1, 14, 21, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 22, 8, 2, 25, 28, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 23, 8, 3, 25, 28, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 24, null, 4, 32, 35, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 25, null, 5, 39, 42, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 26, null, 6, 47, 49, false);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 1, null, 7, 55, 60, true);
INSERT INTO category_activitys (case_category_id, activity_id, contact_type_id, activity_order, warning_days, deadline_days, mandatory)
VALUES (412, 7, null, 8, 65, 70, true);


INSERT INTO decision_types (decision_type_id, decision_type_name) VALUES (1, 'Ruling');
INSERT INTO decision_types (decision_type_id, decision_type_name) VALUES (2, 'Interlocutory Judgment');
INSERT INTO decision_types (decision_type_id, decision_type_name) VALUES (3, 'Final Judgment');
INSERT INTO decision_types (decision_type_id, decision_type_name) VALUES (4, 'Sentencing');
INSERT INTO decision_types (decision_type_id, decision_type_name) VALUES (5, 'Decree');
SELECT setval('decision_types_decision_type_id_seq', 6);

INSERT INTO order_types (order_type_id, order_type_name) VALUES (1, 'Witness Summons');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (2, 'Warrant of Arrest');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (3, 'Warrant of Commitment to Civil Jail');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (4, 'Language Understood by Accused');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (5, 'Release Order - where cash bail has been paid');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (6, 'Release Order - where surety has signed bond');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (7, 'Release Order');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (8, 'Committal Warrant to Medical Institution/Mathare Mental Hospital');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (9, 'Escort to Hospital for treatment, Age assessment or mental assessment');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (10, 'Judgment Extraction');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (11, 'Particulars of Surety');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (12, 'Others');
INSERT INTO order_types (order_type_id, order_type_name) VALUES (14, 'Warrant of commitment on remand');
SELECT setval('order_types_order_type_id_seq', 15);

INSERT INTO receipt_types (receipt_type_id, receipt_type_name, receipt_type_code) VALUES (1, 'Traffic Fine', 'TR');
INSERT INTO receipt_types (receipt_type_id, receipt_type_name, receipt_type_code) VALUES (2, 'Criminal Fine', 'CR');
INSERT INTO receipt_types (receipt_type_id, receipt_type_name, receipt_type_code) VALUES (3, 'Filing Fee', 'FF');
SELECT setval('receipt_types_receipt_type_id_seq', 14);

INSERT INTO payment_types (payment_type_id, payment_type_name, cash) VALUES (1, 'Cash Receipt', true);
INSERT INTO payment_types (payment_type_id, payment_type_name) VALUES (2, 'KCB Bank Payment');
INSERT INTO payment_types (payment_type_id, payment_type_name, for_credit_note) VALUES (3, 'Credit Note', true);
INSERT INTO payment_types (payment_type_id, payment_type_name, for_refund) VALUES (4, 'Refund', true);
SELECT setval('payment_types_payment_type_id_seq', 5);

DELETE FROM entity_types WHERE entity_type_id = 3;

INSERT INTO entity_types (entity_type_id, use_key_id, entity_type_name) VALUES (10, 0, 'Lawyer');
INSERT INTO entity_types (entity_type_id, use_key_id, entity_type_name) VALUES (11, 0, 'Insurance Firm');
UPDATE entity_types SET org_id = 0;


